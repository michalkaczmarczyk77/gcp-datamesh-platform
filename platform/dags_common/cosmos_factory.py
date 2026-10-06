from pathlib import Path
import yaml
from cosmos import DbtTaskGroup, ProjectConfig, ProfileConfig, ExecutionConfig, RenderConfig, LoadMode

# git-sync mounts the repo here; "domains" is the subPath configured in values-<env>.yaml.
DAGS_ROOT = Path("/opt/airflow/dags/repo/domains")


def load_manifest(domain: str) -> dict:
    return yaml.safe_load((DAGS_ROOT / domain / "domain.yaml").read_text())


def dbt_task_group(domain: str, select: list[str] | None = None) -> DbtTaskGroup:
    project_dir = DAGS_ROOT / domain / "dbt"
    return DbtTaskGroup(
        group_id=f"dbt_{domain}",
        project_config=ProjectConfig(
            dbt_project_path=project_dir,
            # Parse from a pre-compiled manifest: avoids running `dbt ls` on every scheduler loop.
            manifest_path=project_dir / "target" / "manifest.json",
        ),
        profile_config=ProfileConfig(
            profile_name=domain,
            target_name="{{ var.value.get('dtp_env', 'dev') }}",
            profiles_yml_filepath=project_dir / "profiles.yml",
        ),
        execution_config=ExecutionConfig(
            dbt_executable_path="/home/airflow/.local/bin/dbt",  # baked into the custom image, see platform/docker/airflow
        ),
        render_config=RenderConfig(
            load_method=LoadMode.DBT_MANIFEST,
            select=select or [],
            test_behavior="after_each",
        ),
        operator_args={"install_deps": False, "full_refresh": False},
        default_args={"retries": 2},
    )
