# IBM Cloud - Logging In using the CLI

When you login via the CLI you need to set the org, the space and the resource group.  Using --cf sets the org and space to point to the cloud foundry area.

```
ibmcloud login
```

Set the Org and Space to the Cloud Foundry, which is a public Kubernetes cluster.

```
ibmcloud target --cf
```

Set your resource group, for an individual account this is normally *Default*.  For the UHI account this will **NOT** be *Default* but will have been given to you by the delivery staff specifically for your project.

```
ibmcloud target -g Default
```

## For help

For help with most ibmcloud commands you can use --help.

```
ibmcloud target --help
```

## To find your resource group type

```
ibmcloud resource groups
```

## To list orgs

```
ibmcloud account orgs
```

## To list spaces 

To list space you have to set an org (replace IBM222222 with the org from the previous command):

```
ibmcloud target -o IBM222222
ibmcloud account spaces
```