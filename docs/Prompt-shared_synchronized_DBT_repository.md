# Propmpt 1

Do not look into my repository just focus on the following case.
Context: Airflow (orchestrator), Astronomer Cosmos, DBT deployed on Kubernetes cluster using Helm Chart
What I know is:
- Astronomer Cosmos acts as a bridge between Airflow and DBT models
- Astronomer Cosmos needs access to DBT models and manifest.json file
- There are conflicts between Airflow libraries and DBT python libraries. Therefore DBT environment should be as much as possible, separated from Airflow. I'd like to deploy DBT models in separate Kubernetes POD.

What I'd like to achieve and what problems I have:
- I'd like Airflow with Cosmos be set in  KubernetesExecutor mode
- I already prepared distinct Docker images. One for DBT only, and another one for the Airflow with Cosmos libraries onboarded. 
- I don't want to rebuild DBT image each time model has changed. I'd preffer to use gitSync sidecar instead, to continuously synchronize my git repository with: cosmos and dbt.
- My understanding of the matter is that both Airflow with Cosmos and DBT Pods, must have access to the same DBT models, wynchronized with Git beforehand.

My question is, how to build such solution when Airflow with Cosmos and DBT have acces to the same repository, synchronized by gitSync.
Or maybe I am wrong... There should be another component installed rather thang gitSync.

Give an advice, and show me how to solve my problem

# Prompt 2: gitSync


General recommendation is to use git-sync with local volumes only, and if you want to it with persistence, you need to make sure that the persistence solution you use is POSIX-compliant and you monitor the side-effects it might have.