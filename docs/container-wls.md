# WebLogic Container

This **`weblogic-buildpack`** is a [Cloud Foundry][] custom buildpack for running JVM-based web applications on [Oracle WebLogic Application Server][] as Application Container.
It is designed to run WebLogic-based Web or EAR applications on WebLogic Server with minimal configuration on CloudFoundry.
This buildpack is based on a fork of the [java-buildpack][].

A single server WebLogic Domain configuration with deployed application would be created by the buildpack.
The complete bundle of the server and application bits would be used to create a droplet for execution within Cloud Foundry.

## Features

* Download and install Oracle WebLogic and JDK binaries from a user-configured location.

* Configure a single server default WebLogic Domain. Configuration of the domain and subsystems would be determined by the configuration bundled with the application or the buildpack.

* JDBC Datasources and JMS services are supported with domain configuration options. WebLogic Server can use a non-XA JDBC datasource to also store [Transaction Logs] [].

* WebLogic Server can be configured to run in limited footprint mode (no support for EJB, JMS, known as WLX mode) or in full mode.

* Standard domain configurations are supported and able to be overridden by the application or the buildpack.

* Scale the number of application instances via ‘cf scale’, not through increasing number of managed servers in the domain.

* The Application can be a single WAR (Web Archive) or EAR (multiple war/jar modules bundled within one Enterprise Archive).

* Its possible to expose the WebLogic Admin Console as another application, all within the overall context of the CF application endpoint (like testapps.xip.io)

* JDBC Datasources will be dynamically created based on Cloud Foundry Services bound to the application.

* Option to bundle patches, drivers, dependencies into the server classpath as needed.

* CF machinery will monitor and automatically take care of restarts as needed, rather than relying on WebLogic Node Manager.

* Its possible to bundle different configurations (like heap or jdbc pool sizes etc) for various deployments (Dev, Test, Staging, Prod) and have complete control over the configuration that goes into the domain and or recreate the same domain every time.

## Detection

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td>
    <td>Existence of one of the following in the application directory
           <ul>
           <li> a <tt>WEB-INF/ folder</tt> </li>
           <li> or <tt>APP-INF/ folder </tt> </li>
           <li> or <tt>.wls/ either under the app or WEB-INF or APP-INF</tt> folder </li>
           <li> or <tt>weblogic*.xml</tt> deployment descriptor </li>
           </ul>
           and <a href="container-java_main.md">Java Main</a> not detected
    </td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><tt>weblogic=&lang;version&rang;</tt> </tt> <i>(optional)</i></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

## Configuration
For general information on configuring the buildpack, refer to [Configuration and Extension][].

The container can be configured by modifying the [`config/weblogic.yml`][] file in the buildpack fork.  The container uses the [`Repository` utility support][repositories] and so it supports the [version syntax][] defined there.

| Name | Description
| ---- | -----------
| `weblogic.repository_root` | The URL of the WebLogic repository index ([details][repositories]).
| `weblogic.version` | The version of WebLogic Server to use.
| `prefer_app_config` | Use Application bundled configuration to drive domain creation.
| `start_in_wlx_mode` | To start the WebLogic Server in restricted mode (purely as Servlet container with no support for JMS, EJBs - [details][limited footprint]).

## Requirements

* WebLogic Server and JDK Binaries
   * The WebLogic Server release bits and jdk binaries should be accessible for download from a user-defined server (can be internal or public facing) for the buildpack to create the necessary configurations along with the application bits.
     Download the [Linux 64 bit JRE][] version and [WebLogic Server][] generic version.

     For testing in a [bosh-lite][] environment, create a loopback alias on the machine so the download server hosting the binaries is accessible from the droplet container during staging.
   
     Sample script for Mac
	 
     ```
        #!/bin/sh
        ifconfig lo0 alias 12.1.1.1

     ```

   * Edit the repository_root of [oracle_jre.yml](config/oracle_jre.yml) to point to the location hosting the Oracle JRE binary.
   
     Sample **`repository_root`** for oracle_jre.yml (under weblogic-buildpack/config)
     
	  ```
       repository_root: "http://12.1.1.1:7777/fileserver/jdk"
	  ````

      The buildpack would look for an **`index.yml`** file at the specified **repository_root** for obtaining jdk related bits.
      The index.yml at the repository_root location should have a entry matching the jdk/jre version and the corresponding jdk binary file
     
      ```
        ---
          1.7.0_51: http://12.1.1.1:7777/fileserver/jdk/jdk-7u55-linux-x64.tar.gz
       ```
       Ensure the JRE binary is available at the location indicated by the index.yml referred by the jre repository_root

   * Edit the repository_root of [weblogic.yml](config/weblogic.yml) to point to the server hosting the WebLogic binary.

     Sample **`repository_root`** for weblogic.yml (under weblogic-buildpack/config)

      ```
      version: 12.1.+
      repository_root: "http://12.1.1.1:7777/fileserver/wls"
      prefer_app_config: false

      ```

	  The buildpack would look for an **`index.yml`** file at the specified **repository_root** for obtaining WebLogic related bits.
	  The index.yml at the repository_root location should have a entry matching the WebLogic server version and the corresponding release bits

# WebLogic Domain Config

The **`weblogic-buildpack`** creates a WebLogic Server Domain using a domain configuration yaml file present under the **`.wls`** folder of the application.

The [weblogic.yml](../config/weblogic.yml) file within the buildpack is used to specify the WebLogic Server Binary download site.
It also manages some configurations used for the WLS Domain creation.

   * The WebLogic Server release bits and jdk binaries should be accessible for download from a server (can be internal or public facing) for the buildpack to create the necessary configurations along with the app bits.
     Download the [Linux 64 bit JRE][] version and [WebLogic Server][] generic version.

   * Edit the repository_root of [weblogic.yml](config/weblogic.yml) to point to the server hosting the weblogic binary.

     Sample `repository_root` for weblogic.yml (under weblogic-buildpack/config)

      ```
      --
        version: 12.1.+
        repository_root: "http://12.1.1.1:7777/fileserver/wls"
        preferAppConfig: false
        startInWlxMode: false

      ```

      The buildpack would look for an `index.yml` file at the specified repository_root url for obtaining WebLogic related bits.
      The index.yml at the repository_root location should have a entry matching the weblogic server version and the corresponding release bits

      ```
        ---
          12.1.2: http://12.1.1.1:7777/fileserver/wls/wls1212_dev.zip

      ```
      Ensure the WebLogic Server binary is available at the location indicated by the index.yml referred by the weblogic repository_root.

      If one has to use a different version (like 10.3.6), make the binaries available on the fileserver location and update the index.yml to include the version and binary location.
      Sample index.yml file content when the file server is hosting the binaries of both 10.3.6 and 12.1.2 versions:

      ```
        ---
          12.1.2: http://12.1.1.1:7777/fileserver/wls/wls1212_dev.zip
          10.3.6: http://12.1.1.1:7777/fileserver/wls/wls1036_dev.zip

      ```

      Update the weblogic.yml (under weblogic-buildpack/config) in buildpack to use the correct version.

      ```

      version: 10.3.6
      repository_root: "http://12.1.1.1:7777/fileserver/wls"

      ```

      Use **`10.3.+`** notation if the server should the latest version under the 10.3 series.
      So, if both 10.3.6 and 10.3.7 binaries are available, the buildpack will automatically choose 10.3.7 over 10.3.6.

      Similarly, update the oracle_jre.yml as needed to switch between versions (while also updating the index.yml to point to the other available versions of jdk).


* Cloud Foundry Release version and manifest update

   * The Cloud Foundry Cloud Controller (cc) Nginx Engine defaults to a max payload size of 256MB. This setting is governed by the **`client_max_body_size`** parameter in the cc and ccng related properties of the cf manifest file.
   
     ```
	 
     properties:
       ...
       cc:
         app_events:
           cutoff_age_in_days: 31
         ....
         bulk_api_password: bulk-password
         client_max_body_size: 256M
       ....
       ccng:
         app_events:
           cutoff_age_in_days: 31
         app_usage_events:
           cutoff_age_in_days: 31
         ....
         bulk_api_password: bulk-password
         client_max_body_size: 256M
     
	 ```
	 
     The Cloud Foundry DEA droplet containing a zip of the full WebLogic server, JDK/JRE binaries and app bits would exceed 520 MB in size. The *`client_max_body_size`* limit of *256M* would limit the droplet transfer to Cloud Controller and failure during staging.
     The *`client_max_body_size`* attribute within the cf-manifest file should be updated to allow *750MB (or higher)* depending on size of the application bits.

     Sample manifest with updated *client_max_body_size*:

     ```

     properties:
       ...
       cc:
         app_events:
           cutoff_age_in_days: 31
         ....
         bulk_api_password: bulk-password
         client_max_body_size: 1024M
       ....
       ccng:
         app_events:
           cutoff_age_in_days: 31
         app_usage_events:
           cutoff_age_in_days: 31
         ....
         bulk_api_password: bulk-password
         client_max_body_size: 1024M

	 ```

     * CF Releases prior to **`v157`** used to hardcode the *`client_max_body_size`* to *256M*. So, overriding it with the manifest entry will not work unless the bosh-lite or hosting environment has been updated to *`v158`* or higher Cloud Foundry release.

     * Oracle WebLogic 12c (v12.1.2) only Development release bits packaged as a zip file (under 200 MB ) can be used with just the JRE. However, full installs (over 800MB of WebLogic Server bundled with or without other products bits) in form of Jar file would require full JDK and not just JRE. All of these would affect the size of the droplet, pushing it much beyond 1GB in size which would require increased client_max_body_size settings in the above mentioned cf deployment manifest settings.

## Application configuration

The buildpack looks for the presence of a **`.wls`** folder within the app at the APP-INF or WEB-INF or root level as part of the detect call to proceed further.
In the absence of the **`.wls`** folder, it will look for presence of weblogic*xml files to detect it as a WebLogic specific application.
Additional configurations and scripts packaged within the **`.wls`** folder would determine the resulting WebLogic Domain and services configuration generated by the buildpack.

The buildpack can override some of the configurations (jdbc/jms/..) while allowing only the app bundled domain config to be used for droplet execution using **prefer_app_config** setting.
Please refer to [Overriding App Bundled Configuration](#overriding-app-bundled-configuration) section for more details.


   * Sample App structure

     Sample Web Application (WAR) structure
     ```
	 
              META-INF/
              META-INF/MANIFEST.MF
              WEB-INF/
              WEB-INF/lib/
              WEB-INF/web.xml
              WEB-INF/weblogic.xml
              WEB-INF/.wls/
              WEB-INF/.wls/foreignjms/
              WEB-INF/.wls/foreignjms/foreignJmsConfig1.yml
              WEB-INF/.wls/jdbc/
              WEB-INF/.wls/jdbc/jdbcDatasource1.yml
              WEB-INF/.wls/jdbc/jdbcDatasource2.yml
              WEB-INF/.wls/jms/
              WEB-INF/.wls/jms/jmsConfig.yml
              WEB-INF/.wls/postJars/
              WEB-INF/.wls/postJars/README.txt
              WEB-INF/.wls/preJars/
              WEB-INF/.wls/preJars/README.txt
              WEB-INF/.wls/script/
              WEB-INF/.wls/script/wlsDomainCreate.py
              WEB-INF/.wls/security/
              WEB-INF/.wls/security/securityConfig.yml
              WEB-INF/.wls/wlsDomainConfig.yml
              index.jsp

       ```

     Sample Enterprise Application (EAR) structure
     ```

              META-INF/
              META-INF/MANIFEST.MF
              META-INF/application.xml
              APP-INF/
              APP-INF/lib/
              APP-INF/classes
              webapp1.war
              webapp2.war
              APP-INF/.wls/
              APP-INF/.wls/foreignjms/
              APP-INF/.wls/foreignjms/foreignJmsConfig1.yml
              APP-INF/.wls/jdbc/
              APP-INF/.wls/jdbc/jdbcDatasource1.yml
              APP-INF/.wls/jdbc/jdbcDatasource2.yml
              APP-INF/.wls/jms/
              APP-INF/.wls/jms/jmsConfig.yml
              APP-INF/.wls/postJars/
              APP-INF/.wls/postJars/README.txt
              APP-INF/.wls/preJars/
              APP-INF/.wls/preJars/README.txt
              APP-INF/.wls/script/
              APP-INF/.wls/script/wlsDomainCreate.py
              APP-INF/.wls/security/
              APP-INF/.wls/security/securityConfig.yml
              APP-INF/.wls/wlsDomainConfig.yml

       ```

   * Domain configuration (non-mandatory)
   
     The **`.wls`** folder should contain a single yaml file that contains information about the user credentials for the target domain.
     There is a sample [Domain config ](resources/wls/wlsDomainConfig.yml) bundled within the buildpack that can be used as a template to modify/extend the resulting domain.
	 
	 Refer to [domain](docs/container-wls-domain.md) for more details.
	 
   * Scripts (non-mandatory)
   
     There can be a **`script`** folder within **`.wls`** with a WLST jython script, for generating the domain
     There is a sample [Domain creation script](resources/wls/script/wlsDomainCreate.py) bundled within the buildpack that can be used as a template to modify/extend the resulting domain.
     
	 Refer to [script](docs/container-wls-script.md) for more details.

   * JDBC Datasources related configuration (non-mandatory)
   
     There can be a **`jdbc`** folder within **`.wls`** with multiple yaml files, each containing configuration relating to datasources (single or multi-pool).
     There is a sample [JDBC config](resources/wls/jdbc/jdbcDatasource1.yml) bundled within the buildpack that can be used as a template to modify/extend the resulting domain with additional datasources.
     
	 Refer to [jdbc](container-wls-jdbc.md) for more details.
	 
   * JMS Resources related configuration (non-mandatory)
   
     There can be a **`jms`** folder within **`.wls`** with a yaml file, containing configuration relating to jms resources
     There is a sample [JMS config](resources/wls/jms/jmsConfig.yml) bundled within the buildpack that can be used as a template to modify/extend the resulting domain with JMS Destinations/Connection Factories.
	 
	 Refer to [jms](container-wls-jms.md) for more details.
     	 
   * Foreign JMS Resources related configuration (non-mandatory)
   
     There can be a **`foreignjms`** folder within **`.wls`** with a yaml file, containing configuration relating to Foreign jms resources
     There is a sample [Foreign JMS config](resources/wls/foreignjms/foreignJmsConfig.yml) bundled within the buildpack that can be used as a template to modify/extend the resulting domain with Foreign JMS Services.
     	 
	 Refer to [foreignjms](docs/container-wls-foreignjms.md) for more details.

   * Security Resources related configuration (non-mandatory)
   
     There can be a **security** folder within **.wls** with a yaml file, containing configuration relating to security configuration
     Add security related configurations as needed and update the domain creation script to use those configurations to modify/extend the resulting domain.
   	 
   * Pre and Post Jar folders (non-mandatory)
   
     The **`preJars`** folder within **`.wls`** can contain multiple jars or other resources, required to be loaded ahead of the WebLogic related jars. This can be useful for loading patches, debug jars, other resources that should override the bundled WebLogic jars.
   
     The **`postJars`** folder within **`.wls`** can contain multiple jars or other resources, required to be loaded after the WebLogic related jars. This can be useful for loading JDBC Drivers, Application dependencies or other resources as part of the server classpath.

   * External Services bound to the Application
     * Services that are bound to the application via the Service Broker functionality would be used to configure and create related services in the WebLogic Domain.
       * The **VCAP_SERVICES** environment variable would be parsed to identify MySQL, PostGres or other services and create associated configurations in the resulting domain.
       * The services can be either from [Pivotal Web Services Marketplace][] or [User Provided Services][] (like internal databases or services managed by internal Administrators and user applications just connect to it).
         * Sample User-Provided JDBC Service (bound to oracle db):

           ```

           cf cups GlobalDataSourceXA -p '{ "label" : "oracle",  "xaProtocol": "TwoPhaseCommit", "jndiName": "jdbc/GlobalDataSourceXA", "driver": "oracle.jdbc.xa.client.OracleXADataSource", "initCapacity": 1, "maxCapacity": 4, "username": "scott", "password": "tiger", "hostname": "10.10.10.6", "jdbcUrl": "jdbc:oracle:thin:@10.10.10.6:1521:xe" }'

           cf bind-service medrec MedRecGlobalDataSourceXA

           ```

         This would lead to the creation of a JDBC Datasource within the server configuration with **JNDI Name : jbdc/GlobalDataSourceXA**

         * Sample User-Provided JMS Service (uses non-persistence messaging):
           ```
           cf cups JMS-SampleJMSService -p ' { "label": "jms-server", "jmsServer" : "TestJmsServer-1", "moduleName": "TestJmsMod-1", "queues": "com.test.jms.CreateQueue;com.test.jms.UpdateQueue;" }'

           cf bind-service SampleTestApp JMS-SampleJMSService

           ```

         This would lead to the creation of a JMS Server within the server configuration comprising of two Queues with **JNDI Names : com.test.jms.CreateQueue and com.test.jms.UpdateQueue **

## Usage

To use this buildpack specify the URI of the repository when pushing an application to Cloud Foundry:

```
cf push -b https://github.com/pivotal-cf/weblogic-buildpack <APP_NAME> -p <APP_BITS>
```

While working in sandbox env against Bosh-Lite, its also possible to use a modified version of the buildpack without github repository using the zip format of the buildpack.
**Note:** Use zip to create the buildpack (rather than jar) to ensure the detect, compile, release files under bin folder have execute permissions during the actual building of the app.

```
cf create-buildpack weblogic-buildpack weblogic-buildpack.zip 1 --enable
```

This would allow CF to use the weblogic-buildpack ahead fo the pre-packaged java-buildpack (that uses Tomcat as the default Application Server).

## CF App Push
A domain would be created based on the configurations and script passed with the app by the buildpack on `cf push` command.

The droplet containing the entire WebLogic install, domain and application bits would be get executed (with the app specified jvm settings and generated/configured services) by Cloud Foundry.
A single server instance would be started as part of the droplet execution. The WebLogic Listen Port of the server would be controlled by the warden container managing the droplet.

The number of application instances can be scaled up or down using cf scale command. This would trigger multiple copies of the same droplet (identical server configuration and application bits but different server listen ports) to be executing in parallel.

Note: Ensure `cf push` uses **`-m`** argument to specify a minimum process memory footprint of 1024 MB (1GB). Failure to do so will result in very small memory size for the droplet container and the jvm startup can fail. 
'-t' option can be used to specify the timeout period (time for server to come up and start listening before warden kills it)
Sample cf push: 

````
cf push wlsSampleApp -m 1024M -p wlsSampleApp.war -t 100
```

## Additional features:
* As part of the release phase, a [preStart.sh](../resources/wls/hooks/preStart.sh) script is executed before starting the actual server. This script handles the following:
  * Recreating the same directory structure in runtime env as compared to staging env 
    The WebLogic install and domain configurations scripts are hardcoded with Staging env structure.
    But the actual directories differs in Staging (/tmp/staged) vs Runtime (/home/vcap)
  * Add -Dapplication.name, -Dapplication.space , -Dapplication.ipaddr and -Dapplication.instance-index
    as JVM arguments to help identify the server instance from other instances within a DEA VM.
    Example: -Dapplication.name=wls-test -Dapplication.instance-index=0
             -Dapplication.space=sabha -Dapplication.ipaddr=10.254.0.210
  * Renaming of the server to include instance index 
    For example: myserver becomes myserver-5 when running with app instance '5'.
    This ensures each instance uses its own database TLOG table for storing its transaction logs (refer to [jdbc](container-wls-jdbc.md)) 
  * Resizing of the heap settings based on actual MEMORY_LIMIT variable in the runtime environment.
    Example: During initial cf push, memory was specified as 1GB and so heap sizes were hovering around 700M.
             Now, user uses cf scale to change memory settings to 2GB or 512MB
    
    The factor to use is deterined by doing division of Actual vs. Staging and heaps are resized by that factor for actual runtime execution without requiring full staging for new instances.
    Sample resizing :
    ```
              Detected difference in memory limits of staging and actual Execution environment !!
                 Staging Env Memory limits: 512m
                 Runtime Env Memory limits: 1512m
              Changing heap settings by factor: 2.95
              Staged JVM Args: -Xms373m -Xmx373m -XX:PermSize=128m -XX:MaxPermSize=128m  -verbose:gc ....
              Runtime JVM Args: -Xms1100m -Xmx1100m -XX:PermSize=377m -XX:MaxPermSize=377m -verbose:gc ....
    ```
* As part of the release phase, a [postStop.sh](../resources/wls/hooks/postStop.sh) script is executed after the actual server has stopped or crashed.
  This script will report the death of the instance along with instructions on downloading any relevant files
  from the specific instance and also provide a default grace period of 30 seconds before the warden container gets destroyed.
  Modify the postStop.sh script as needed to copy/transfer files to a central shared repository for further analysis.
  Sample output:
  ```
     2014-09-16T13:31:54.08-0700 [App/1]   OUT App Instance went down either due to user action or other reasons!!
     2014-09-16T13:31:54.08-0700 [App/1]   OUT                   App Details
     2014-09-16T13:31:54.08-0700 [App/1]   OUT ---------------------------------------------------------------
     2014-09-16T13:31:54.08-0700 [App/1]   OUT  Name of Application    : wls-tlog-test
     2014-09-16T13:31:54.08-0700 [App/1]   OUT  App GUID               : 4d2030f9-c871-48c3-b1b0-a1d2760fb164
     2014-09-16T13:31:54.08-0700 [App/1]   OUT  Space                  : sabha
     2014-09-16T13:31:54.08-0700 [App/1]   OUT  Instance Index         : 1
     2014-09-16T13:31:54.08-0700 [App/1]   OUT  Warden Container Name  : 182o1o2j6v9
     2014-09-16T13:31:54.08-0700 [App/1]   OUT  Warden Container IP    : 10.254.1.78
     2014-09-16T13:31:54.08-0700 [App/1]   OUT  Start time             : 2014-09-16 19:29:55 +0000
     2014-09-16T13:31:54.08-0700 [App/1]   OUT  Stop time              : 2014-09-16 20:31:54 +0000
     2014-09-16T13:31:54.08-0700 [App/1]   OUT ---------------------------------------------------------------
     2014-09-16T13:31:54.08-0700 [App/1]   OUT Shutdown wait interval set to 30 seconds (using env var 30, default 30)
     2014-09-16T13:31:54.08-0700 [App/1]   OUT Modify this script as needed to upload core files, logs or other dumps to some remote file server
     2014-09-16T13:31:54.08-0700 [App/1]   OUT Use cf curl to download the relevant files from this particular instance
     2014-09-16T13:31:54.08-0700 [App/1]   OUT     cf curl /v2/apps/4d2030f9-c871-48c3-b1b0-a1d2760fb164/instances/1/files
     2014-09-16T13:31:54.08-0700 [App/1]   OUT Container will exit after 30 seconds!!
     2014-09-16T13:32:24.09-0700 [App/1]   OUT Container exiting!!!

  ```
  The grace period before complete removal of the container can be controlled by specifying the **SHUTDOWN_WAIT_INTERVAL** environment variable (use cf set-env option) for the application. This value will be treated as the number of seconds to wait before the container can be cleaned up (after exit of the main java app instance).

  Sample command:
  ```
     cf set-env wls-tlog-test SHUTDOWN_WAIT_INTERVAL 120
  ```

## Examples

Refer to [WlsSampleWar](resources/wls/WlsSampleApp.war), a sample web application packaged with sample configurations under the resources/wls folder of the buildpack.
There is also a sample ear file [WlsSampleApp.ear](resources/wls/WlsSampleApp.ear) under the same location.

## Buildpack Development and Testing
* There are 3 stages in the buildpack: **`detect`**, **`compile`** and **`release`**. These can be invoked manually for sandbox testing.
  * Explode or extract the webapp or artifact into a folder
  * Run the <weblogic-buildpack>/bin/detect <path-to-exploded-app>
    * This should report successful detection on locating the **`.wls`** at the root of the APP-INF or WEB-INF folder 

    Sample output:
    ```

    $ weblogic-buildpack/bin/detect wlsSampleApp
    oracle-jre=1.7.0_51 weblogic-buildpack=https://github.com/pivotal-cf/weblogic-buildpack.git#b0d5b21 weblogic=12.1.2

    ```

  * Run the <weblogic-buildpack>/bin/**compile** <path-to-exploded-app> <tmp-folder>
    * This should start the download and configuring of the JDK, WebLogic server and the WLS Domain based on configurations provided.
    * If no temporary folder is provided as second argument during compile, it would report error.

     ```ERROR Compile failed with exception #<RuntimeError: Application cache directory is undefined> ```

    Sample output for successful run:

    ```

    $ weblogic-buildpack/bin/compile wlsSampleApp tmp1
    -----> WebLogic Buildpack source: https://github.com/pivotal-cf/weblogic-buildpack.git#2cf927f6632af73a5b4f55c591a3e3ce14f2378f
    -----> Downloading Oracle JRE 1.7.0_51 from http://12.1.1.1:7777/fileserver/jdk/jre-7u51-linux-x64.tar.gz (0.1s)
           Expanding Oracle JRE to .java-buildpack/oracle_jre "Got command tar xzf t1/http:%2F%2F12.1.1.1:7777%2Ffileserver%2Fjdk%2Fjre-7u51-linux-x64.tar.gz.cached -C /Users/sparameswaran/workspace/wlsSampleApp2/.java-buildpack/oracle_jre --strip 1 2>&1"
    (0.6s)
    -----> Downloading Weblogic 12.1.2 from http://12.1.1.1:7777/fileserver/wls/wls1212_dev.zip (0.8s)
    -----> Expanding WebLogic to .java-buildpack/weblogic
    (4.4s)
    -----> Configuring WebLogic under .java-buildpack/weblogic
           Warning!!! Running on Mac, cannot use linux java binaries downloaded earlier...!!
           Trying to find local java instance on Mac
           Warning!!! Using JAVA_HOME at /Library/Java/JavaVirtualMachines/jdk1.7.0_51.jdk/Contents/Home/jre/bin/..
    -----> Finished configuring WebLogic Domain under .java-buildpack/weblogic/domains/cfDomain
    (1m 34s)

    ```

  * Run the <weblogic-buildpack>/bin/**release** <path-to-exploded-app>
    * This should report the final JVM parameters and or other java options and as well as execution script that would be used for the Droplet execution.

    Sample output:

    ```

    $ weblogic-buildpack/bin/release wlsSampleApp
    ---
    addons: []
    config_vars: {}
    default_process_types:
      web: JAVA_HOME=$PWD/.java-buildpack/oracle_jre USER_MEM_ARGS="-Xms404m -Xmx404m
        -XX:PermSize=128m -XX:MaxPermSize=128m  -verbose:gc -Xloggc:gc.log -XX:+PrintGCDetails
        -XX:+PrintGCTimeStamps -XX:-DisableExplicitGC -Djava.security.egd=file:/dev/./urandom  -Djava.io.tmpdir=$TMPDIR
        -XX:OnOutOfMemoryError=$PWD/.java-buildpack/oracle_jre/bin/killjava.sh -Dweblogic.ListenPort=$PORT"
        sleep 10; /bin/bash ./preStart.sh; /bin/bash /Users/sparameswaran/workspace/wlsSampleApp/.monitor/dumperAgent.sh
        ; /Users/sparameswaran/workspace/wlsSampleApp/WEB-INF/wlsInstall/domains/wlsSampleAppDomain/startWebLogic.sh;
        /bin/bash ./postStop.sh
    ```

* The buildpack would log the status and progress during the various execution stages into the .java-buildpack.log folder underneath the exploded-app directory.
  This log can be quite useful to debugging any issues or changes.

* The complete JDK/JRE and WebLogic Server install as well as the domain would be created under the APP-INF or WEB-INF folder as wlsInstall folder of the exploded application.

  Structure of the App, JDK and WLS Domain

  ```

  Exploded WebApp Root
     |-META-INF
     |-WEB-INF
     |---.wls                     <----------- WLS configuration folder referred by weblogic-buildpack
     |----foreignjms
     |----jdbc
     |----jms
     |----security
     |----script                  <----------- WLST python script goes here
     |-.java-buildpack.log        <----------- buildpack log file
     |-.java-buildpack            <----------- buildpack created folder
     |--lib
     |--oracle_jre                <----------- JRE install·
     |----bin
     |----lib
     |--weblogic                  <----------- WebLogic install
     |----domains
     |------cfDomain              <----------- WebLogic domain
     |--------app
     |----------ROOT              <----------- Root of App deployed to server
     |--------autodeploy
     |--------config
     |---wlsInstall               <----------- wl_home
     |------coherence
     |------logs
     |------oracle_common
     |------wlserver

  ```

## Running WLS with limited footprint 

The generated WebLogic server can be configured to run with a limited runtime footprint by avoiding certain subsystems like  EJB, JMS, JCA etc.  This option is controlled by the **start_in_wlx_mode** flag within the weblogic-buildpack [config](docs/container-wls.md)

      ```
      version: 12.1.+
      repository_root: "http://12.1.1.1:7777/fileserver/wls"
      prefer_app_config: false
      start_in_wlx_mode: false
      ```


Setting the **start_in_wlx_mode** to true would disable the EJB, JMS and JCA layers and reducing the overall memory footprint required by WLS Server. This is ideal for running pure web applications that don't use EJBs or messaging.  If there are any EJBs or jms modules/destinations configured, the activation of the resources will result in errors at server startup.

Setting the **start_in_wlx_mode** to false would allow the full blown server mode.

Please refer to the WebLogic server documentation on the [limited footprint][] option for more details.

## Overriding App Bundled Configuration

The **`prefer_app_config`** parameter specified inside the [weblogic.yml](config\weblogic.yml) config file of the buildpack controls whether the buildpack or application bundled config should be used for Domain creation.

The weblogic-buildpack can override the app bundled configuration for subsystems like jdbc, jms etc.
The script for generating the domain would be pulled from the buildpack configuration (under resources/wls/script).

But the name of the domain, server and user credentials would be pulled from Application bundled config files so each application can be named differently.


      ```
      version: 12.1.+
      repository_root: "http://12.1.1.1:7777/fileserver/wls"
      prefer_app_config: false

      ```

Setting the  **`prefer_app_config`** to **`true`** would imply the app bundled configs (under .wls of the App Root) would always be used for final domain creation.
Setting the parameter to **`false`** would imply the buildpack's configurations (under resources\wls\) have higher precedence over the app bundled configs and be used to configure the domain.
The Application supplied domain config file would be used for names of the domain, server, user credentials.

For users starting to experiment with the buildpack and still tweaking and reconfiguring the generated domain, **`prefer_app_config` should be enabled so they can experiment more easily**.
This would allow the app developer to quickly change/rebuild the domain to achieve the desired state rather than pushing changes to buildpack and redeploy the application also each time.

**On reaching the desired domain configuration state (Golden state), save the configurations and scripts into the buildpack and disable the `prefer_app_config` parameter when no further changes are allowed or necessary to the domain.
One can also modify the domain creation script to lock down or block access to the WebLogic Admin Console or override the domain passwords, once the desired domain configuration has been achieved.**

*Note:
 The Cloud Foundry services that are injected as part of the registered Service Bindings for the application would still be used to create related services during application deployment.
 The Domain Administrators are expected to use the Service Bindings to manage/control the services that are exposed to the application as it moves through various stages (Dev, Test, PreProd, Prod).


## Remote Triggering of Thread Dumps, Stats and Heap from App Instances

The WebLogic Buildpack kicks off background scripts that can pick trigger signals received via cf files in form of access of a designated target file to kick off the data collection.
The sample scripts are packaged under the resources/wls/monitoring folder.

Check the [Remote Diagnostics for Applications][] blog post for more details. Also refer to the [Monitoring](container-wls-monitoring.md) documentation.
Sample bundled scripts (under ../resources/wls/monitoring) can be used to trigger thread or heap dumps as well as collect system statistics/metrics across all instances of the deployed application.

# Managing JVM Arguments
Users can add additional jvm arguments by setting the JAVA_OPTS environment variable via the cf set-env cli command. 
Note: Ensure you use the latest version of cf cli to set the environment variables.

```
$ cf se test-app JAVA_OPTS '-verbose:gc -Djava.net.preferIPv4=true -Dmy.application.name=test-app'
Setting env variable 'JAVA_OPTS' to '-verbose:gc  -Djava.net.preferIPv4=true -Dmy.application.name=test-app' for app test-app in org sabha / space sabha as admin...
OK
TIP: Use 'cf push' to ensure your env variable changes take effect
```

## Potential Issues

* Oracle WebLogic 12c (v12.1.2) Development release bits containing only WebLogic Server packaged as a zip file (under 200 MB ) can be used with just the JRE. However, full installs (over 800MB) of WebLogic Server, bundled with or without other products bits, in form of Jar file would require full JDK and not just JRE. The buildpack would fail during the install of the WebLogic install binaries if just used against JRE. This will also affect the size of the droplet, pushing it beyond 1GB in size. Ensure corresponding increase in the client_max_body_size settings in the cf deployment manifest.

* If the application push fails during the **`Uploading droplet`** phase, either the client_max_body_size is too small or the controller managing bosh-lite is running out of disk space. Either edit the deployment manifest and redeploy to bosh or clean up the **`/var/vcap/store/10.244.0.34.xip.io-cc-droplets/`** folder contents inside the api_z1/0 instance (use bosh ssh api_z1 0 command to login into the controller).

* If download of the JDK/JRE or WLS binaries fails during the compile stage or if it reports of `EROFS: Read-only file system`, it would mean the complete url to the binary is missing and the buildpack is attempting to load it from within the DEA whichw ould fail. 

Complete stack trace:
```
-----> Downloaded app package (40K) 
-----> WebLogic Buildpack Version: unknown 
[Buildpack] ERROR Compile failed with exception #
<Errno::EROFS: Read-only file system - /var/vcap/data/dea_next/admin_buildpacks/3a047ff3-c03c-4313-a2df-9ade25469cd0_0c84eb7cdd9b94656fb4c4b8dd6f4018d81db399/resources/cache> 
Read-only file system - /var/vcap/data/dea_next/admin_buildpacks/3a047ff3-c03c-4313-a2df-9ade25469cd0_0c84eb7cdd9b94656fb4c4b8dd6f4018d81db399/resources/cache 
/var/vcap/packages/dea_next/buildpacks/lib/installer.rb:19:in `compile': Buildpack compilation step failed: (RuntimeError) 
from /var/vcap/packages/dea_next/buildpacks/lib/buildpack.rb:74:in `block in compile_with_timeout' 
from /usr/lib/ruby/1.9.1/timeout.rb:68:in `timeout' 
from /var/vcap/packages/dea_next/buildpacks/lib/buildpack.rb:73:in `compile_with_timeout' 
from /var/vcap/packages/dea_next/buildpacks/lib/buildpack.rb:54:in `block in stage_application' 
from /var/vcap/packages/dea_next/buildpacks/lib/buildpack.rb:50:in `chdir' 
from /var/vcap/packages/dea_next/buildpacks/lib/buildpack.rb:50:in `stage_application'
from /var/vcap/packages/dea_next/buildpacks/bin/run:10:in `<main>' 
-----> Downloading Oracle JRE 1.7.0_60 from jre-7u60-linux-x64.gz 
```

Ensure the index.yml files for the jdk or weblogic binaries has the complete url including the host and protocol scheme specified.
For jdk/jre:

      ```
        ---
          1.7.0_51: http://12.1.1.1:7777/fileserver/jdk/jdk-7u55-linux-x64.tar.gz
      ```

For WebLogic binary bits:
      ```
        ---
          12.1.2: http://12.1.1.1:7777/fileserver/wls/wls1212_dev.zip
      ```
* If the app fails to get detected by the weblogic buildpack and reports `Permission denied` problem, then it means the detect (and other scripts like compile and release) don't have execute permissions. Rebuild the zip after adding execute permissions to the files under bin folder of the weblogic buildpack.

Error Message
```
Failed to run buildpack detection script with error: Permission denied - /var/vcap/data/dea_next/admin_buildpacks/2d2b4e9c-c0be-444c-a393-4a44cd6d6a20_c0916d71e6ba03a35924f674c46f52ff045d3310/bin/detect /tmp/staged/app
...

Staging failed: An application could not be detected by any available buildpack
...
Server error, status code: 400, error code: 170001, message: Staging error: cannot get instances since staging failed

```

* If the detect fails right away with Psych:SyntaxError messages, problem could be caused by commented portions interrupting the Ruby Psych parsing logic
Remove or move the commented portions out of the valid sequence - so the jdk or java containers does not hit this error.
Might be caused by the commented entries inside the config/components.yml file for frameworks or containers 

Error Description

```
-----> Downloaded app package (88K)
Cloning into '/tmp/buildpacks/weblogic-buildpack'...
-----> WebLogic Buildpack Version: 195519b | https://.../weblogic-buildpack
/usr/lib/ruby/1.9.1/psych.rb:203:in `parse': (#<File:0x0000000125c5a0>): mapping values are not allowed in this context at line 2 column 13 (Psych::SyntaxError)
  from /usr/lib/ruby/1.9.1/psych.rb:203:in `parse_stream'
  from /usr/lib/ruby/1.9.1/psych.rb:151:in `parse'
  from /usr/lib/ruby/1.9.1/psych.rb:127:in `load'
  from /usr/lib/ruby/1.9.1/psych.rb:297:in `block in load_file'
  from /usr/lib/ruby/1.9.1/psych.rb:297:in `open'
  from /usr/lib/ruby/1.9.1/psych.rb:297:in `load_file'
  from /tmp/buildpacks/weblogic-buildpack/lib/java_buildpack/repository/repository_index.rb:42:in `block in initialize'
  from /tmp/buildpacks/weblogic-buildpack/lib/java_buildpack/util/cache/cached_file.rb:51:in `call'
  from /tmp/buildpacks/weblogic-buildpack/lib/java_buildpack/util/cache/cached_file.rb:51:in `block in cached'
  from /tmp/buildpacks/weblogic-buildpack/lib/java_buildpack/util/cache/cached_file.rb:51:in `open'
  from /tmp/buildpacks/weblogic-buildpack/lib/java_buildpack/util/cache/cached_file.rb:51:in `open'
  from /tmp/buildpacks/weblogic-buildpack/lib/java_buildpack/util/cache/cached_file.rb:51:in `cached'
  from /tmp/buildpacks/weblogic-buildpack/lib/java_buildpack/util/cache/download_cache.rb:66:in `get'

```

* If the buildpack appears to be stuck or hung at Domain creation (configuration/install completed but not the domain creation), then its possible the WLST script is blocked on random number generation for the Domain security credentials. Upgrade to the latest buildpack version which uses urandom to generate the secure random numbers.

* Additional Buildpack logging on failures

 If the buildpack fails during detect or other phases, enable `JBP_LOG_LEVEL` to `debug` using `cf set-env` command (`cf set-env app_name JBP_LOG_LEVEL debug`).
 Then run `cf push` again followed by `cf logs --recent` to get the full details for the cause of the failure.

```
hammerkop:workspace sparameswaran$ cf set-env test-appJBP_LOG_LEVEL debug
Setting env variable 'JBP_LOG_LEVEL' to 'debug' for app test-app in org sabha / space sabha as admin...
OK
TIP: Use 'cf push' to ensure your env variable changes take effect

hammerkop:workspace sparameswaran$ cf push test-app -p test -t 100
Updating app test-app in org sabha / space sabha as admin...
OK

Uploading test-app...
Uploading app files from: test
Uploading 19.9K, 7 files
OK

Stopping app test-app in org sabha / space sabha as admin...
OK

Starting app test-app in org sabha / space sabha as admin...
OK

FAILED
Server error, status code: 400, error code: 170001, message: Staging error: cannot get instances since staging failed

TIP: use 'cf logs test-app --recent' for more information
hammerkop:workspace sparameswaran$ cf logs test-app --recent
Connected, dumping recent logs for app test-app in org sabha / space sabha as admin...

.....
2014-06-19T13:04:53.02-0700 [STG]     ERR [Buildpack]                      DEBUG Instantiating JavaBuildpack::Container::Weblogic
2014-06-19T13:04:53.03-0700 [STG]     ERR [Buildpack]                      DEBUG Successfully required JavaBuildpack::Container::Weblogic
2014-06-19T13:04:53.03-0700 [STG]     ERR [Weblogic]                       DEBUG Running Detection on App: /tmp/staged/app
2014-06-19T13:04:53.03-0700 [STG]     ERR [Weblogic]                       DEBUG   Checking for presence of .wls folder under root of the App or weblogic deployment descriptors within App
2014-06-19T13:04:53.03-0700 [STG]     ERR [Weblogic]                       DEBUG   Does .wls folder exist under root of the App? :
2014-06-19T13:04:53.03-0700 [STG]     ERR [Weblogic]                       DEBUG WLS Buildpack Detection on App: /tmp/staged/app failed!!!
2014-06-19T13:04:53.03-0700 [STG]     ERR [Weblogic]                       DEBUG Checked for presence of .wls folder under root of the App  or weblogic deployment descriptors within App
2014-06-19T13:04:53.03-0700 [STG]     ERR [Weblogic]                       DEBUG   Do weblogic deployment descriptors exist within App?   : false
2014-06-19T13:04:53.03-0700 [STG]     ERR [Weblogic]                       DEBUG   Or is it a simple Web Application with WEB-INF folder? : false
2014-06-19T13:04:53.03-0700 [STG]     ERR [Weblogic]                       DEBUG   Or is it a Enterprise Application with APP-INF folder? : false
2014-06-19T13:04:53.03-0700 [STG]     ERR [Weblogic]                       DEBUG   Or does .wls folder exist under root of the App?       : false
2014-06-19T13:04:53.03-0700 [STG]     ERR [Buildpack]                      DEBUG Detection Tags: []

```

## Limitations (as of April, 2014)

* CF release version should be equal or greater than v158 to allow overriding the client_max_body_size for droplets (the default is 256MB which is too small for WebLogic droplets). If using a much larger binary image of the WebLogic Server (like the jar version of WebLogic and Coherence server that itself is in excess of 800 MB in size), then the the droplet size will easily exceed 1GB in addition to the JDK binaries and application bits.

* Only HTTP inbound traffic is allowed. No inbound RMI communication is allowed. There cannot be any peer-to-peer communication between WebLogic Server instances.

* There is no support for multiple servers or clusters within the domain. An admin server would be running with the application(s) deployed to it. In-memory session replication/high-availability is not supported.

* Only stateless applications are supported.
  * The server will start with a brand new image (on an entirely different VM possibly) on restarts and hence it cannot rely on state of previous runs.
  The file system is ephemeral and will be reset after a restart of the server instance. This means Transaction recovery is not supported after restarts.
  This also includes no support for persistent messaging using file stores.
  WebLogic LLR for saving transaction logs on database and JDBC JMS store options are both not possible as the identify of the server would be unique and different on each run.

* Changes made via the WebLogic Admin Console will not persist across restarts for the same reasons mentioned previously, domain customizations should be made at staging time using the buildpack configuration options.

* Server logs are transient and are not available across restarts on the container file system, however can have Cloud Foundry loggregator send logs to a [syslog drain endpoint like Splunk][].

* The buildpack does not handle security aspects (Authentication or Authorization). It only uses the embedded ldap server for creating and using the single WebLogic Admin user. Its possible to extend apply security policies by tweaking the domain creation.

* Only base WebLogic domains are currently supported. There is no support for other layered products like SOA Suite, Web Center or IDM in the buildpack.

[Apache License]: http://www.apache.org/licenses/LICENSE-2.0
[bosh-lite]: http://github.com/cloudfoundry/bosh-lite/
[Cloud Foundry]: http://www.cloudfoundry.com
[Configuration and Extension]: ../README.md#configuration-and-extension
[contributor guidelines]: ../CONTRIBUTING.md
[GitHub's forking functionality]: https://help.github.com/articles/fork-a-repo
[Grails]: http://grails.org
[Groovy]: http://groovy.codehaus.org
[Installing Cloud Foundry on Vagrant]: http://blog.cloudfoundry.com/2013/06/27/installing-cloud-foundry-on-vagrant/
[java-buildpack]: http://github.com/cloudfoundry/java-buildpack/
[Linux 64 bit JRE]: http://javadl.sun.com/webapps/download/AutoDL?BundleId=83376
[Linux 64 bit JDK]: http://download.oracle.com/otn-pub/java/jdk/7u55-b13/jdk-7u55-linux-x64.tar.gz
[limited footprint]: http://docs.oracle.com/middleware/1212/wls/START/overview.htm#START234
[Oracle WebLogic Application Server]: http://www.oracle.com/technetwork/middleware/weblogic/overview/index.html
[Pivotal Web Services Marketplace]: http://docs.run.pivotal.io/marketplace/services/
[Play Framework]: http://www.playframework.com
[pull request]: https://help.github.com/articles/using-pull-requests
[Pull requests]: http://help.github.com/send-pull-requests
[Remote Diagnostics for Applications]: http://blog.gopivotal.com/cloud-foundry-pivotal/products/remote-triggers-for-applications-on-cloud-foundry
[Spring Boot]: http://projects.spring.io/spring-boot/
[syslog drain endpoint like Splunk]: http://www.youtube.com/watch?v=rk_K_AAHEEI
[User Provided Services]: http://docs.run.pivotal.io/devguide/services/user-provided.html
[version syntax]: extending-repositories.md#version-syntax-and-ordering
[Transaction Logs]: http://docs.oracle.com/cd/E23943_01/web.1111/e13701/store.htm#BABDACFH
[WebLogic Server]: http://www.oracle.com/technetwork/middleware/weblogic/downloads/index.html

