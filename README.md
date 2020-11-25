# Saleor Helm Charts

This is an unofficial registry of [Saleor](https://saleor.io/) 
[helm](https://helm.sh/) charts.

## Prerequisites
* [Helm](https://helm.sh/) 3+

## Setup

Add the saleor helm repo:
```console
$ make helm.setup
```

## Installation
To install Saleor chart archives on your machine run the following command

```console
$ make install
```

You're all set!
 
### Exposing the apps
The apps are not exposed yet, here's what you need to do so that 
you can access them from your machine:

```console
$ make expose
```

`$*_SERVICE_PORT` is the port of the running service in a pod. You can find 
them under `containerPort` in `deployment.yaml` files. So far, they are set to 
the following:

|      Service      | Port |
|:------------------|:----:|
| saleor            | 8000 |
| Saleor-dashboard  | 8080 |
| Saleor-storefront | 8080 |

### Using bash
Bash is extremely helpful in running management commands on your services. To 
enter the bash shell of a pod use the following command

```console
$ make POD_NAME=<pod_name> bash
```

### Don't forget
Configure a values.yaml for the chart you want to install.

## List of Charts

### [saleor](./charts/saleor)
Chart to run [Saleor](https://github.com/mirumee/saleor) with the 
[Dashboard](#dashboard) and [Storefront](#storefront).

> Note: This chart will not only installs Saleor backend, it also installs 
> Saleor dashboard and storefront charts along the way. 

### [dashboard](./charts/dashboard)
Chart to run [Saleor Dashboard]()

### [storefront](./charts/storefront)
Chart to run [Saleor Storefront](https://github.com/mirumee/saleor-storefront).

## Package and deploy updated charts
Deploy requires [`cr`](https://github.com/helm/chart-releaser) tool 

### Enable Github Pages (only first time)
Settings > Options > Github Pages > Source > Select master branch

### Package chart

```console
$ make chart.package
```

### Upload New Release

```console
$ make chart.release
```

> Note: This command assumes that you have a Github token set in $CR_TOKEN
> environment variable.

### Generate new index

```console
$ make chart.index
```
