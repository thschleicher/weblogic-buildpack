# WebLogic Domain Config

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
              WEB-INF/.wls/
              WEB-INF/.wls/foreignjms/
              WEB-INF/.wls/foreignjms/foreignJmsConfig1.yml
              WEB-INF/.wls/jdbc/
              WEB-INF/.wls/jdbc/jdbcDatasource1.yml
              WEB-INF/.wls/jdbc/jdbcDatasource2.yml
              WEB-INF/.wls/jms/
              WEB-INF/.wls/jms/jmsConfig.yml
              WEB-INF/.wls/postJars/
              WEB-INF/.wls/preJars/
              WEB-INF/.wls/preJars/README.txt
              WEB-INF/.wls/script/
              WEB-INF/.wls/script/wlsDomainCreate.py                 <--------- WLST Script
              WEB-INF/.wls/security/
              WEB-INF/.wls/security/securityConfig.yml
              WEB-INF/.wls/wlsDomainConfig.yml                       <--------- Domain Config file

       ```

The contents of the domain config file specify the name and password of the admin user.
Additionally, it can also specify whether to enable Console and Production Mode.
The Domain name and server names would be auto-configured based on the name of the application being pushed.
The parameters are used by the buildpack during creation of the domain using the wlst script provided along with the application.
Presence of this file along with the script is mandatory for creation of the WebLogic Domain.

Sample domain config (from [wlsDomainConfig.yml](resources/wls/wlsDomainConfig.yml)
```

# Configuration for the WebLogic Domain
---

# Need mainly user and password filled in
# Will figure out domain name and server name based on application name from VCAP_APPLICATION Env variable
#

Domain:
  wlsUser: weblogic
  wlsPasswd: welcome1
  consoleEnabled: true
  prodModeEnabled: false

```

* **`wlsUser`** denotes the name of the admin user
* **`wlsPaswd`** denotes the password of the admin user
* **`consoleEnabled`** enables or disables WLS Admin Console deployment
* **`prodModeEnabled`** enables or disables Production Mode in WLS.