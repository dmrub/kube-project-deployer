# Kubernetes Project Deployer

## Components

This configuration uses combination of Kubernetes [Kustomize](https://kustomize.io/) format and [Mustache](https://mustache.github.io/) template with [mo](https://github.com/tests-always-included/mo) preprocessor.

In first step configuration from file `settings.cfg` is used to generate YAML configuration files in Kustomize format.
Then Kustomize configuration is applied to Kubernetes cluster.

## Requirements

You need to install openssl, git, and [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) or OpenShift CLI [oc](https://docs.openshift.com/container-platform/3.11/cli_reference/get_started_cli.html) for your platform. Scripts are written in bash and tested on Linux.

## Usage

1. Link or copy `minikube.cfg` and `settings.cfg` from one of the subdirectories of the `config-examples` directory to the directory where this file is located.
2. For using [minikube](https://minikube.sigs.k8s.io/) install it first then edit `minikube.cfg` file and set USE_MINIKUBE variable to yes: `USE_MINIKUBE=yes`.
3. If you use OpenShift, log in with the `oc login` command, if you use Kubernetes switch to the Kubernetes context which you want to use for deployment.
4. Run the command `scripts/print-kubectl-config.sh` and add the printed lines to the file `settings.cfg` or replace them.
5. Customize `settings.cfg` if needed.
6. Run the `init.sh` script. It will initialize development environment.
7. Start or stop services by running `servicectl.sh` script:
   ```
    $ ./servicectl.sh --help
    Start project services

    ./servicectl.sh [command]
    command:
    start             start services
    stop              stop services
    status            print status of services
    help              print this

   ```
9.  If you have changed the configuration to `*.cfg` files, you will need to update files generated from mustache templates by running the script `scripts/preprocess-templates.sh'.
