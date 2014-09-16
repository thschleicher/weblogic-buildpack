# WebLogic JDBC Config

The **`weblogic-buildpack`** creates a WebLogic Server Domain using a domain configuration yaml file present under the **`.wls`** folder of the application.

Sample Web Application (WAR) structure

     ```
              META-INF/
              META-INF/MANIFEST.MF
              WEB-INF/
              WEB-INF/lib/
              WEB-INF/web.xml
              WEB-INF/weblogic.xml
              index.jsp
              .wls/
              .wls/foreignjms/
              .wls/foreignjms/foreignJmsConfig1.yml
              .wls/jdbc/
              **.wls/jdbc/jdbcDatasource1.yml                  <--------- JDBC Config 1**
              **.wls/jdbc/jdbcDatasource2.yml                  <--------- JDBC Config 2**
              .wls/jms/
              .wls/jms/jmsConfig.yml
              .wls/jvm/
              .wls/jvm/jvmConfig.yml
              .wls/postJars/
              .wls/postJars/README.txt
              .wls/preJars/
              .wls/preJars/README.txt
              .wls/script/
              **.wls/script/wlsDomainCreate.py                 <--------- WLST Script**
              .wls/security/
              .wls/security/securityConfig.yml
              **.wls/wlsDomainConfig.yml                       <--------- Domain Config file**

       ```

The contents of the jdbc config files specify the parameters used for creation of JDBC Datasources to be available on the WebLogic Server.

The same JDBC Datasource configuration can be created using user-provided service bindings without using the yaml file.

Example:

       ```
       cf cups GlobalDataSourceXA -p '{ "label" : "oracle",  "xaProtocol": "TwoPhaseCommit", "jndiName": "jdbc/GlobalDataSourceXA", "driver": "oracle.jdbc.xa.client.OracleXADataSource", "initCapacity": 1, "maxCapacity": 4, "username": "scott", "password": "tiger", "hostname": "10.10.10.6", "jdbcUrl": "jdbc:oracle:thin:@10.10.10.6:1521:xe" }'

       cf bind-service medrec MedRecGlobalDataSourceXA
       ```


Sample Multipool jdbc config (from [jdbcDatasource1](resources/wls/jdbc/jdbcDatasource1.yml)

```
# Configuration for the WebLogic JDBC Datasources
---

# Each section deals with a subsystem
# Use | character to provide multiple entries as in jdbc server endpoints
# ex: localhost:1531:orcl1|localhost:1541:orcl2|localhost:1551:orcl3
#
# For Multipool, only 2 algorithms are supported: Load-Balancing or Failover
#
# For xaProtocols, only valid values are:
# TwoPhaseCommit, LoggingLastResource, EmulateTwoPhaseCommit, OnePhaseCommit, None
# XA Drivers should be tagged as TwoPhaseCommit
# Non-XA Drivers can use all the other 4 options (LLR, 1PC, 2PC, None - shortened for brevity)

JDBCDatasource-1:
  # Is Multipool
  isMultiDS: true
  # Use Load-Balancing or Failover
  mp_algorithm: Load-Balancing
  # JdbcUrlPrefix is the driver url without the ':@' followed by hostname/port/service data - required for Multipool
  jdbcUrlPrefix: jdbc:oracle:thin
  # Use the | pipe character to delimit the various hosts that form the underlying datasources for the multipool
  jdbcUrlEndpoints: localhost:1531:orcl1|localhost:1541:orcl2|localhost:1551:orcl3
  name: MultiDatasource-1
  jndiName: jdbc/testJDBCDSMulti
  driver: oracle.jdbc.xa.client.OracleXADataSource
  username: testUser1
  password: testPasswd1
# For xaProtocols, only valid values are:
# TwoPhaseCommit, LoggingLastResource, EmulateTwoPhaseCommit, OnePhaseCommit, None
# XA Drivers should be tagged as TwoPhaseCommit
# Non-XA Drivers can use all the other 4 options (LLR, 1PC, 2PC, None - shortened for brevity)
  xaProtocol: TwoPhaseCommit
  initCapacity: 5
  maxCapacity: 40
  # Lower the time duration for recreation of connection pool on failure or outage (like 30 seconds)
  connectionCreationRetryFrequency: 900
  testSql: SQL SELECT 1 from DUAL

```

Simple jdbc config (from [jdbcDatasource2](resources/wls/jdbc/jdbcDatasource2.yml)

```

---
JDBCDatasource-2:
  isMultiDS: false
  jdbcUrl: jdbc:oracle:thin:@localhost:1521:orcl
  name: Datasource-1
  jndiName: jdbc/testJDBCDSSingle
  driver: oracle.jdbc.OracleDriver
  username: testUser
  password: testPasswd
  xaProtocol: None
  initCapacity: 5
  maxCapacity: 30
  # Lower the time duration for recreation of connection pool on failure or outage (like 30 seconds)
  connectionCreationRetryFrequency: 900
  testSql: SQL SELECT 1 from DUAL
  use_for_tlog: true

```
* Description of Parameters:

 * **`isMultiDS`** denotes usage of Multi-pools to access multiple database instances to provide high availability and failover.
 If enabled (set to true), ensure the **`jdbcUrlPrefix`** and **`jdbcUrlEndpoints`** are specified.

   * The **`jdbcUrlPrefix`** should refer to the jdbc url portion without the server endpoint and service name
   * The **`jdbcUrlEndpoints`** should specify the server and service names.
     Sample:
     ```
      # **`jdbcUrlPrefix`** is the driver url without the ':@' followed by hostname/port/service data - required for Multipool
      jdbcUrlPrefix: jdbc:oracle:thin
      # Use the **`|`** pipe character to delimit the various hosts that form the underlying datasources for the multipool
      jdbcUrlEndpoints: localhost:1531:orcl1|localhost:1541:orcl2|localhost:1551:orcl3
      ```
   * **`mp_algorithm`** should be either **`Load-Balancing`** or **`Failover`** depending on nature of usage of the database instances.

 * **`jndiName`** would refer to the datasource JNDI Name

 * **`initCapacity`** would used for creating an initial number of connections in the pool.

 * **`maxCapacity`** would determine the maximum number of connections allowed in the pool under load.

 * **`testSQL`** would be the sql used to test the health of the connections in the pool.

 * **`connectionCreationRetryFrequency`** would the time period to wait between retries to recreate the connections in the pool on previous failures.
   Setting this parameter to low intervals would allow faster recovery after failures; Setting it to higher value would delay the recovery but avoid overwhelming the database under heavy load all at once due to the connection recreation.

 * **`username`** and `password`** are credentials used for connecting to the database instance.

 * **`driver`** can be either non-XA or XA driver.

 * Based on the driver type, specify the **`xaProtocol`**.
   * For XA Drivers, specify `TwoPhaseCommit` as value for the **`xaProtocol`**
   * For non-XA Drivers, there are three options that can be specified against **`xaProtocol`**
     * Use **`None`** if the datasource should not participate in Global Transactions
     * Use **`OnePhaseCommit`** if the datasource should participate in a global transaction without any additional participants.
     * Use **`EmulateTwoPhaseCommit`** if the datasource needs to be participate in global transaction with XA using the emulate option.
     * Use **`LoggingLastResource`** option if the datasource can use LLR option.

 * **`use_for_tlog`** will denote whether to use this datasource for storing WebLogic [Transaction Logs][] on the database rather than default file store.
   * The Datasource should be using a non-XA Driver
   * The `xaProtocol` type should be `OnePhaseCommit` or `None` (cannot be Global or LLR or Emulate 2-PC Commits)

   * Actual generated TLog table name would be ${app}Server${instanceIndex}WLSTORE
     Example: for a 'test-cf' app with app instance '0', the table name would be test-cfServer0WLSTORE
     Ensure the app name is not too long so the total string does not exceed 30... otherwise following error would be thrown
     Use this with caution, due to the length limitation as well as possibility for same app deployed to different spaces but using same database logins can lead to duplicates.
     Adding the space name to the field/table name leads to more possiblity for hitting the 30 character limits.
     ```
     For a app with name: sabha-wls-tlog-test, generated name is SABHAWLS_TLOG_TESTSERVER1WLSTORE
     2014-09-16T11:54:04.99-0700 [App/0]   OUT <Sep 16, 2014 6:54:04 PM UTC> <Error> <Store> <BEA-280072> <JDBC store "sabha-wls-tlog-testServer-0JTA_JDBCTLOGStore" failed to open table "TLOG_sabha-wls-tlog-testServer-0WLStore".
     2014-09-16T11:54:04.99-0700 [App/0]   OUT java.sql.SQLException: [Store:280063]The "table" field value "SABHAWLS_TLOG_TESTSERVER1WLSTORE" in table reference "SABHAWLS-TLOG-TESTSERVER1WLSTORE" (format [[[catalog.]schema.]table) is too long. The database supports a maximum length of "30" for this field.
     2014-09-16T11:54:04.99-0700 [App/0]   OUT 	at weblogic.store.io.jdbc.JDBCHelper.checkLength(JDBCHelper.java:203)
     2014-09-16T11:54:04.99-0700 [App/0]   OUT 	at weblogic.store.io.jdbc.JDBCHelper.createTableIdentifier(JDBCHelper.java:246)
     2014-09-16T11:54:04.99-0700 [App/0]   OUT 	at weblogic.store.io.jdbc.JDBCHelper.getDMLIdentifier(JDBCHelper.java:177)
     2014-09-16T11:54:04.99-0700 [App/0]   OUT 	at weblogic.store.io.jdbc.JDBCStoreIO.initialize(JDBCStoreIO.java:691)

     ```

     Long app and space names can stop the tlog creation as the actual table name is comprised of the ${Space}${app}Server${instanceIndex}WLSTORE



   Note: Since the WebLogic server instance running on Cloud Foundry does not have a true restart option as well as no persistent store for saving and recovering the transaction logs, using XA and global transactions is limited to the lifetime of the server instance.
   The above XA options would work as long as the server instance is up and running but all transaction logs are lost on death of the server as any instance would a brand new entity with no awareness of its earlier state (or pending transactions).

   Refer to [Oracle WebLogic Server Transactions][] documentation for more details on Global Transaction options.

 * Default are used for other datasource options (like Test connections on reserve, Shrinking, XA Options etc.).
   Modify the domain creation script as needed. Refer to [Oracle WebLogic Server JDBC Config][] documentation for more details.

# References

[Transaction Logs] http://docs.oracle.com/cd/E23943_01/web.1111/e13701/store.htm#BABDACFH
[Oracle WebLogic Server JDBC Config] (http://docs.oracle.com/cd/E12839_01/web.1111/e13737/jdbc_datasources.htm)
[Oracle WebLogic Server Transactions] (http://docs.oracle.com/cd/E12839_01/web.1111/e13737/jdbc_datasources.htm#JDBCA144)
