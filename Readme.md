# IBM Cloud Scripts

These are some scripts I put together to help use IBM Cloud everyday in a learning environment.

## Prerequisites

This has been tested with Ubuntu and Fedora.  If you try it with other distributions let us know of any bugs!

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
./install.sh
export PATH=$PATH:$(pwd)
```

You will want to add the following to your .bashrc or .bash_profile file:
```
export PATH=$PATH:<location of ibmcloud-scripts>
```

We recommend you create an api key for yourself to save you some typing!  Keep this safe though.

```
./ibm_create_login_key.sh
```



