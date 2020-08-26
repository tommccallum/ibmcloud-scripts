# IBM Cloud Scripts

These are some scripts I put together to help use IBM Cloud everyday in a learning environment.

## Prerequisites

1. Get a IBM Cloud account setup

2. Download and install git
```
ubuntu$ sudo apt -y install git
fedora$ sudo dnf -y install git
```

3. Get the IBM Cloud CLI as per the instructions here [https://cloud.ibm.com/docs/cli](https://cloud.ibm.com/docs/cli).

## Installation

```
git clone https://github.com/tommccallum/ibmcloud-scripts
cd ibmcloud-scripts
export PATH=$PATH:$(pwd)
```

You will want to add the following to your .bashrc or .bash_profile file:
```
export PATH=$PATH:<location of ibmcloud-scripts>
```