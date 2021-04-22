# Writing a Cloud function to call a stored procedure in DB2

Here we outline some of the knowledge that is required to write stored procedures and connect them to IBM's Cloud Functions.

## Writing a stored procedure

Here we are creating a new stored procedure in our DB2 instance.  It is common in databases to use the word DROP instead of DELETE.  

Note the line ```--#SET TERMINATOR @``` this is required so that the semi-colons do not prematurely end the statement.

Stored procedures have IN and OUT parameters.  IN parameters are values that are used in the stored procedure itself.  OUT parameters will be set.  These are not always supported by drivers so check documentation.  The ```DYNAMIC RESULT SETS 1``` means that the stored procedure will return a single result set (table of results).

The following stored procedure will return a CURSOR, a pointer to the first record of the matching result set.

Stored procedures can be written in other languages which is why we specify that the language is SQL.

```
DROP PROCEDURE IF EXISTS my_stored_procedure;

--#SET TERMINATOR @
CREATE PROCEDURE my_stored_procedure(IN id INTEGER) LANGUAGE SQL 
 DYNAMIC RESULT SETS 1 
 BEGIN
	DECLARE C1 CURSOR WITH RETURN TO CLIENT FOR SELECT * FROM QQJ90050.CUSTOMER  WHERE CUSTOMER_ID=id;
	OPEN C1;
	RETURN;
 END@
```

## The Action Javascript

```
/**
  *
  * main() will be run when you invoke this action
  *
  * @param Cloud Functions actions accept a single parameter, which must be a JSON object.
  *
  * @return The output of this action, which must be a JSON object.
  *
  */
var ibmdb = require('ibm_db');

function findCustomers(dsn, queryCustID) {
    var conn=ibmdb.openSync(dsn);
    if ( typeof(queryCustID) == "undefined") {
        queryCustID = 1
    }

    // METHOD 1:
    // Write SQL directly, here we use a PREPARED STATEMENT.
    // Note the use of placeholder question marks.  We have one for each variable.
    // DO NOT USE STRING CONCATENATION TO CREATE SQL QUERIES - EVER!
    //const data = conn.querySync("SELECT * FROM CUSTOMER WHERE CUSTOMER_ID=?",[queryCustID])

    // METHOD 2:
    // Here we call our STORED PROCEDURE to do the SELECT statement for us.  Notice the CALL keyword.
    var stmt = conn.prepareSync("CALL my_stored_procedure(?)")
    var result = stmt.executeSync([1])

    // METHOD 2.1: capture row by row
    // var data = []
    // let datum;
    // while ( datum = result.fetchSync({fetchMode:3}) ) {
    //     data[data.length] = datum
    // }
    
    // METHOD 2.2: capture all at once (preferred for most scenarios)
    var data = result.fetchAllSync();

    // always close your recordset, this allows the database to close the open cursor of the 
    // stored procedure
    result.closeSync()

    // always close our connections as there is a maximum limit of 5
    conn.closeSync();

    // return our amazing data!
    return { "data": data };
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
    
    return findCustomers(dsn, params.queryCustID);
}
```

## Common Errors

The following error is because you have not specified an alternative statement character.  

```
Error message
An unexpected token "END-OF-STATEMENT" was found following "WHERE CUSTOMER_ID=id".  Expected tokens may include:  "<psm_semicolon>".. SQLCODE=-104, SQLSTATE=42601, DRIVER=4.26.14
```

Solution is to insert this line before the CREATE PROCEDURE
```
--#SET TERMINATOR @
```


## References

* [The ibm_db documentation](https://github.com/ibmdb/node-ibm_db/blob/master/APIDocumentation.md)
* [Languages used to create stored procedures](https://www.ibm.com/docs/en/db2-for-zos/11?topic=procedure-languages-used-create-stored-procedures)
* [DB2 Reference](https://www.ibm.com/docs/en/db2-for-zos/11?topic=db2-sql)