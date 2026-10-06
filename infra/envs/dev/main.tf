# Przygotowanie środowiska dla platformy / domeny.
# Cała konfiguracja brana z plików definicji domenowych domain.yaml

locals {
  domain_files = fileset("${path.module}/../../../domains", "*/domain.yaml")
  domains = { for f in local.domain_files :
    yamldecode(file("${path.module}/../../../domains/${f}")).domain =>
    yamldecode(file("${path.module}/../../../domains/${f}"))
  }

  products = flatten([for d, cfg in local.domains :
    [for p in cfg.produces : merge(p, { domain = d })]
  ])

  consumers_by_topic = { for t in distinct([for p in local.products : p.topic]) :
    t => [for d, cfg in local.domains :
      d if contains([for c in try(cfg.consumes, []) : c.topic], t)]
  }
}

module "domain_identity" {
  for_each   = local.domains
  source     = "../../modules/domain_identity"
  domain     = each.key
  project_id = var.project_id
}

module "airflow" {
  source     = "../../modules/airflow_gke"
  project_id = var.project_id
  env        = var.env
  region     = var.region
}
