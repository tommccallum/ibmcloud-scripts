# Connect IBM Cloud Functions to IBM DB2 Instance

## Services to create

1. A DB2 instance
2. A Nodejs Cloud Foundry Application
3. A Cloud Functions service
4. Connect the Cloud Foundry Application to DB2 instance
5. Generate a Service Credential under Cloud Foundry Service DB2 instance
6. Bind the action to the service


## Logging in using the ClI

```
ibmcloud login
```

If using UHI account then target the appropriate resource group.  If using Lite account target 'Default'. If this does not work then you should go to Manage|Account and Resource Groups to see your default resource group name.

```
ibmcloud target -r <resource group>
```

Connect to Cloud Foundry

```
ibmcloud target --cf 
```

## Connecting your DB2 instance to the Cloud Foundry Application

1. Click on the Cloud Foundry application you have created
2. Click on *Connections*
3. Click on *Create*
4. Select your resource

## Creating Cloud Foundry service key

1. Click on the Cloud Foundry **Service** DB2 instance
2. Select *Service Credentials*
3. Click on *New Credential*

This is the credential you will use in the binding call below.

## Action JS Code

You can copy this code into a test action to see everything working.

```
var ibmdb = require('ibm_db');
/**
  * Set up the necessary Db2 table, insert some data or clean up
  *
  * Written by Henrik Loeser
  */

function db2Setup(dsn, mode) {
 try {
    var tabledef="create table events "+
                 "(eid int not null generated always as identity (start with 1000, increment by 1),"+
                  "shortname varchar(20) not null,"+
                  "location varchar(60) not null,"+
                  "begindate timestamp not null,"+
                  "enddate timestamp not null,"+
                  "contact varchar(255) not null);";
    var sampledata="insert into events(shortname,location,begindate,enddate,contact) values('Think 2019','San Francisco','2019-02-12 00:00:00','2019-02-15 23:59:00','https://www.ibm.com/events/think/'),('IDUG2019','Charlotte','2019-06-02 00:00:00','2019-06-06 23:59:00','http://www.idug.org');"
    var query = "SELECT * FROM events";
    var tabledrop="drop table events;"
    var conn=ibmdb.openSync(dsn);
    if (mode=="setup")
    {
        var data=conn.querySync(tabledef);
    } else if (mode=="sampledata")
    {
      var data=conn.querySync(sampledata);
    } else if (mode=="cleanup")
    {
      var data=conn.querySync(tabledrop);
    } else if ( mode == "query") {
        var data = conn.querySync(query);
    }
    conn.closeSync();
    return {result : data};
 } catch (e) {
     return { dberror : e }
 }
}

function main(params) {
  dsn=params.__bx_creds[Object.keys(params.__bx_creds)[0]].dsn;
  
  // dsn does not exist in the DB2 credential for Standard instance. It must be built manually
  if(!dsn) {
    const dbname = params.__bx_creds[Object.keys(params.__bx_creds)[0]].connection.db2.database;
    const hostname = params.__bx_creds[Object.keys(params.__bx_creds)[0]].connection.db2.hosts[0].hostname;
    const port = params.__bx_creds[Object.keys(params.__bx_creds)[0]].connection.db2.hosts[0].port;
    const protocol = 'TCPIP';
    const uid = params.__bx_creds[Object.keys(params.__bx_creds)[0]].connection.db2.authentication.username;
    const password = params.__bx_creds[Object.keys(params.__bx_creds)[0]].connection.db2.authentication.password;
    
    //dsn="DATABASE=;HOSTNAME=;PORT=;PROTOCOL=;UID=;PWD=;Security=SSL";
    dsn = `DATABASE=${dbname};HOSTNAME=${hostname};PORT=${port};PROTOCOL=${protocol};UID=${uid};PWD=${password};Security=SSL`;

  }
  
  return db2Setup(dsn, params.mode);
}
```
Original Source: [https://github.com/IBM-Cloud/slack-chatbot-database-watson/blob/master/db2-setup.js](https://github.com/IBM-Cloud/slack-chatbot-database-watson/blob/master/db2-setup.js)

## To list the available services

List all available Cloud Foundry services:

```
ibmcloud service list
```

Example output:
```
Invoking 'cf services'...

Getting services in org IBM2126278 / space devuk as someone@example.ac.uk...

name                            service                   plan   bound apps      last operation     broker                   upgrade available
AppID-ca                        AppID                     lite   MARIE           update succeeded   IMFAuthorizationBroker   
Cloudant-aw-gj-65749            cloudantNoSQLDB           lite   webapp-aw-gj    create succeeded   cloudant                 
Cloudant-q1                     cloudantNoSQLDB           lite   MARIE           create succeeded   cloudant                 
Cloudant-same-app-4-ways-5173   cloudantNoSQLDB           lite   sameapp4ways    create succeeded   cloudant                 
db2-example             dashDB For Transactions   Lite   ecommerce-app   create succeeded   dashDBRM 
```

Note the second column is the *service* name used in the functions calls for binding.

## To list the service keys

```
ibmcloud service keys SERVICE_NAME
```

Example:
```
ibmcloud service keys db2-example
```

Example output:
```
Invoking 'cf service-keys db2-example'...

Getting keys for service instance db2-example as someone@example.ac.uk...

name
db2-ecommerce-cf-service-key
```

## To list the available namespaces

Call to list namespaces:
```
ibmcloud fn namespace list
```

Example output:
```
Searching namespaces in selected region: eu-gb
name                  type            id                                    description 
AuthTestNS            IAM-based       b7286402-396c-4733-a402-594986e58e1a  Namespace for OAuth testing
IBM2126278_devuk      CF-based        IBM2126278_devuk                      
Namespace-W6T         IAM-based       9bc90353-7bd2-4a77-92e7-cdd2ae79bbe4  
Namespace-d2C         IAM-based       9e742d8d-c50d-423f-9f4f-7057317f54f8  ECS2
Semester2-lb          IAM-based       cb097da7-0190-4f3f-95d4-4855ae2e0bda 
```

## To connect to a particular action namespace

You need to find to the namespace for it to find your action:

```
ibmcloud fn namespace target Namespace-d2C 
```

Example output:
```
ok: whisk namespace set to Namespace-d2C
```

## Bind the DB2 instance to the action

* Ensure you are using the correct resource group
* Ensure you are logged in (sometimes the CLI times out without saying anything so watch out for that)

```
ibmcloud fn service bind SERVICE ACTION_NAME [--instance INSTANCE_NAME] [--keyname CREDENTIALS_NAME]
```

Example:
```
ibmcloud fn service bind "dashDB For Transactions" test/testdb2creds --instance my-db2 --keyname "cf-db2-service-credential" 
```

## Test the binding

Once bound you can do the following CLI call:

```
ibmcloud fn action get test/testdb2creds parameters 
```

This should print out the parameters passed by default when the action is called in this case:

```
[
    {
        "key": "__bx_creds",
        "value": {
            "dashDB For Transactions": {
                "credentials": "Service credentials-1",
                "db": "BLUDB",
                "dsn": "DATABASE=BLUDB;HOSTNAME=dashdb-txn-sbox-yp-lon02-07.services.eu-gb.bluemix.net;PORT=50000;PROTOCOL=TCPIP;UID=**************;PWD=**************;",
                "host": "dashdb-txn-sbox-yp-lon02-07.services.eu-gb.bluemix.net",
                "hostname": "dashdb-txn-sbox-yp-lon02-07.services.eu-gb.bluemix.net",
                "https_url": "https://dashdb-txn-sbox-yp-lon02-07.services.eu-gb.bluemix.net:8443",
                "instance": "Db2-qk",
                "jdbcurl": "jdbc:db2://dashdb-txn-sbox-yp-lon02-07.services.eu-gb.bluemix.net:50000/BLUDB",
                "parameters": {},
                "password": "**************",
                "port": 50000,
                "ssldsn": "DATABASE=BLUDB;HOSTNAME=dashdb-txn-sbox-yp-lon02-07.services.eu-gb.bluemix.net;PORT=50001;PROTOCOL=TCPIP;UID=**************;PWD=**************;Security=SSL;",
                "ssljdbcurl": "jdbc:db2://dashdb-txn-sbox-yp-lon02-07.services.eu-gb.bluemix.net:50001/BLUDB:sslConnection=true;",
                "uri": "db2://npp64134:01wmlqltn58b%40mcx@dashdb-txn-sbox-yp-lon02-07.services.eu-gb.bluemix.net:50000/BLUDB",
                "username": "**************"
            }
        }
    }
]
```


## Unbind the service

* To unbind the service from the action then you do this:

```
ibmcloud fn service unbind SERVICE_NAME ACTION_NAME
```

Example:
```
ibmcloud fn service unbind "dashDB For Transactions" test/testdb2creds 
```

## Run Action from CLI

```
ibmcloud fn action invoke test/testdb2conn -p mode "[\"setup\"]" -r
ibmcloud fn action invoke test/testdb2conn -p mode "[\"sampledata\"]" -r
ibmcloud fn action invoke test/testdb2conn -p mode "[\"query\"]" -r
ibmcloud fn action invoke test/testdb2conn -p mode "[\"cleanup\"]" -r
```

## ERROR: Security processing failed with reason "24"

If you change the action code you will need to bind and rebind the action otherwise you will get the following error.

```
{
    "dberror": {
        "error": "[node-ibm_db] SQL_ERROR",
        "message": "[IBM][CLI Driver] SQL30082N  Security processing failed with reason \"24\" (\"USERNAME AND/OR PASSWORD INVALID\").  SQLSTATE=08001\n",
        "sqlcode": -30082,
        "state": "08001"
    }
}
```

## References

* [https://cloud.ibm.com/docs/openwhisk?topic=openwhisk-services](https://cloud.ibm.com/docs/openwhisk?topic=openwhisk-services)