# Kontekst projektu

Projekt z założenia był ***"projektem weekendowym"***, czyli szybkim, eksperymentalnym, zakończonym prototypową implementacją procesem wytwórczym: od koncepcji, przez analizę wykonalności, implementację i wdrożenie.

[Draw.io: High Level Conceptual Diagram](docs/WeekendProject.drawio)

Aktualnie nie jest to produkt kompletny gotowy do użycia produkcyjnego. Nie został w pełni przetestowany i obarczony jest (najprawdopodobniej) błędami - które będą eliminowane podczas dalszych prac i testów.

### Sposób podejścia do realizacji projektu

Rozwiązanie zostało wypracowane podczas kilku, kilku-godzinnych sesji z modelem językowym **Claude Opus 5.5**. Do modelu został przekazany pełny kontekst zawierający:

- ogólną koncepcję na której rozwiązanie ma być oparte: Data Mesh z uwzględnieniem pryncypiów DDD
- wytyczne co do implementacji: propozycja komponentów technicznych realizujących zdefiniowane funkcje architektury
- ograniczenia, jakie należy zastosować - wytyczenie granic domen, kontekstów

Praca została podzielona na etapy:

1. **Część analityczna**
  
    Odbywała się w kilku iteracjach. Po każdej z nich, dokonywana była ewaluacja proponowanych przez model rozwiązań. Badane były motywacje, które stały za podjętymi decyzjami. W ramach tych iteracji proponowałem rozważanie innych podejść, które miały być wsadem do wypracowania w kolejnych iteracji.

    Po kilku iteracjach tworzony był dokument analityczny opisujący decyzje, sposób implementacji i rozważane inne rozwiązania. Takie dokument stanowiły element uzupełniający kontekst konwersacji, przed kolejnymi iteracjami. 

2. **Część "generatywna"**

    Ta część również odbywała się w kilku iteracjach. Model działający w trybie *Agent* miał za zadanie wygenerowanie kompletnego repozytorium kodu, zawierającego wszystkie elementy potrzebne do stworzenia i uruchomienia rozwiązania. Na tym etapie, Agent nie uruchamiał i nie tworzył żadnych elementów infrastruktury, jedynie kod i instrukcje jak należy kod wdrożyć. 

    Po każdej iteracji, dostarczony kod był weryfikowany i jeszcze raz ewaluowany z Agentem. W trakcie fazy walidacji, wykonywane były modyfikacje/ulepszanie kodu i budowana była baza wiedzy. 

3. **Część wdrożeniowa**

    Najdłuższy etap projektu. Przeprowadzany ręcznie, krok po kroku. Udział LLM, ograniczał się do udzielania odpowiedzi technicznych dotyczących poszczególnych elementów rozwiązania i poszerzania swojej wiedzy. Model wykorzystywany był również do wsparcia podczas rozwiązywania problemów, których było wiele - począwszy od niekompatybilności bibliotek Python w ramach Docker, skończywszy na kompletnej zmianie sposobu i kolejności deploymentu poszczególnych elementów w ramach klastra GKE.

    Na tym etapie, zostało dokonanych wiele modyfikacji, wcześniej wygenerowanego kodu. Finalnie, całe rozwiazanie zostało wdrożone. Wszystkie komponenty architektury zostały osadzone w ramach GCP. 

    ***Na tym etapie nie zostały wykonane testy funkcjonalne. To zadanie czeka jeszcze w kolejce.***


# Projekt: Data Transformation Platform (Reference Implementation)

Referencyjna implementacja planu opisanego w pliku
[`Weekend-Project-GKE_AirFlow.md`](docs/Weekend-Project-GKE_AirFlow.md):
wielodomenowa platforma transformacji danych w BigQuery, zarządzana przez
**samodzielnie hostowaną instancję Apache Airflow na GKE Autopilot**, wdrażana za pomocą Terraform i
GitHub Actions (bez użycia kluczy, z wykorzystaniem Workload Identity Federation),
gdzie dbt (poprzez astronomer-cosmos) odpowiada za transformacje SQL,
a Pub/Sub przesyła między domenami zdarzenia typu „udostępniono produkt danych” (data product released).

Pełny opis koncepcji, uzasadnienie oraz informacje o alternatywnych rozwiązaniach,
takich jak Cloud Composer czy Eventarc, znajdują się w dokumencie z planem.
Niniejszy folder stanowi *szkielet* opisanej architektury,
gotowy do uzupełnienia i wdrożenia.

## Szkielet rozwiązania

```
.github/workflows/   CI/CD: terraform plan/apply, dbt Slim CI, deploy to GKE
infra/
  bootstrap/         One-time: WIF pool/provider + CI service accounts (applied manually)
  modules/           Reusable Terraform modules (bigquery_domain, airflow_gke, data_product_topic, domain_identity, composer)
  envs/{dev,prd}/    Environment composition - reads domains/*/domain.yaml and wires modules
domains/
  sales/             Autonomous domain unit: dbt project + DAGs + domain.yaml contract
  finance/           Consumes sales.fct_orders via BigQuery source() + Pub/Sub event
platform/
  dags_common/       Shared Airflow plugin code (Cosmos DAG factory, release publisher, freshness guard)
  docker/airflow/    Custom Airflow image (base + cosmos + dbt-bigquery)
  helm/airflow/      Helm values per environment
  scripts/           deploy + domain-manifest validation scripts
```

## Quick start

1. **Bootstrap (jednorazowo, lokalnie):**

  Utworzenie podstawowych komponentów infrastruktury GCP:
  - GCP Projects
  - Storage Buckets: dla plików stanu terraform
  - WIF: pools, providers, bindings
  - Service Accounts & Roles
  - Artifact Registry

  ```bash
  cd infra/bootstrap
  ./bootstrap.sh
  ```
  Skopiować outputy do GitHub Actions sekretów (`WIF_PROVIDER`, `SA_TF_PLAN`, `SA_TF_APPLY`, `SA_DBT_CI`, `SA_DEPLOY`).

2. **Utworzenie środowisk dla Domeny / Platformy:**
   
   Utworzenie pozostałych elementów rozwiązania:
   - Klaster GKE na Autopilocie - wykorzystanie oficjalnego helm chart dla Airflow
   - Cloud SQL - jako baza metadanych dla Airflow
   - BigQuery: data sety i tabele
   - Topiki produktowe Pub/Sub

   Wszystko w formie modułów terraform:
   [`modules/airflow_gke`, `modules/bigquery_domain`, `modules/data_product_topic`]

   ```bash
   cd infra/envs/dev
   terraform init
   terraform apply
   ```
   
3. **Lokalna budowa modeli DBT**:
   ```bash
   cd domains/sales/dbt && dbt deps && dbt build --target dev
   cd domains/finance/dbt && dbt deps && dbt build --target dev
   ```

4. **Push to `main`** — `cd-deploy.yml` budowa obrazu Airflow, push do Git i uruchomienie 
   `helm upgrade`.

5. **Teardown (i pozamiatane):**
   ```bash
   cd infra/envs/prd && terraform destroy
   cd infra/envs/dev && terraform destroy
   ```

## Zasady, konwencje obowiązujące w ramach Domen

- Domena może użyć jedynie `source()` aby użyć datasetów `mart` z innej domeny. Nigdy nie może użyć między-domenowego `ref()` — zob. `domains/finance/dbt/models/staging/_sources.yml`.
- Kontrakt domenowy [`domains/<name>/domain.yaml`]: podstawowe ustawienia dla schedulera,
  produktów Data Products i Konsumenckich Upstream Data Products. 
  (`infra/envs/*/main.tf`) and CI (`platform/scripts/validate_domain_manifest.py`)
- Obecnie wszystko jest konfigurowane centralnie za pomocą pętli `for-each` w pliku `infra/envs/<env>/main.tf`, odnoszącej się do `domain.yaml`. Plik `infra.tf` danej domeny *nie* jest włączony do tego grafu zależności – stanowi on dokumentację dla samodzielnej konfiguracji Terraform, którą domena będzie wykorzystywać po wydzieleniu do własnego repozytorium - Zobacz komentarz np. na początku pliku `domains/sales/infra.tf`.

## Dodatkowe informacje i ustalenia po konwersacji z LLM

The plan's code snippets are illustrative, not a complete repo — a few
pieces were referenced but never fully specified. These were added to make
the scaffold internally consistent and actually runnable:

- **`validate_freshness` + the `_dtp_processed_events` dedup table** (Step
  5.5 described these but never defined them) — implemented in
  `platform/dags_common/freshness.py`, backed by a shared `dtp_platform`
  BigQuery dataset created once in `infra/envs/*/main.tf`.
- **DLQ topic + Pub/Sub IAM bindings** (`google_pubsub_topic.dlq` was
  referenced but never created) — added to `infra/modules/data_product_topic`,
  along with a `dlq_triage` subscription (`dlq_retention_duration`, default 14
  days) so dead-lettered messages are actually pullable/inspectable instead of
  vanishing instantly — a DLQ topic with zero subscriptions holds nothing at
  all, it doesn't accumulate "forever" either. A `google_monitoring_alert_policy`
  fires when `num_undelivered_messages > 0` on that subscription; wire a real
  destination via `dlq_alert_notification_channels` (empty by default — the
  alert still raises an incident in Cloud Monitoring either way, it just won't
  page/email/Slack anyone until channels are supplied). Requires adding
  `monitoring.googleapis.com` to the Step 1.2 API-enablement list.
- **`domain_identity` module** — only referenced by interface in the plan,
  so it was built from scratch (per-domain service account +
  `bigquery.jobUser`).
- **Cloud SQL Auth Proxy sidecar** — the Helm values said `host: 127.0.0.1`
  with no container behind it; added `extraContainers` to
  `platform/helm/airflow/values-{dev,prd}.yaml`.
- **`domains/*/infra.tf`** — documented as *not* wired into the live
  Terraform graph (it would otherwise duplicate what `infra/envs/*/main.tf`'s
  `domain.yaml` for-each loop already provisions). It's what each domain
  becomes standalone with after the Phase 9 repo-extraction split — see the
  header comment in `domains/sales/infra.tf`.
- **`fct_revenue`** — sales' `fct_orders` didn't carry any monetary column,
  so "revenue" would have been meaningless; added an `order_items`/
  `sale_price` join through `stg_order_items.sql` so finance aggregates a
  real `order_value`.
- One genuine bug caught via linting: `ci-dbt.yml` had unquoted `${{ }}`
  inside flow-mapping YAML (`{ }`) syntax, which is invalid YAML — fixed by
  quoting both occurrences.
