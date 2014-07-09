## Remote Triggering of Thread Dumps, Stats and Heap from App Instances

Using a set of shell scripts and the CF CLI interface, it is possible to trigger the data collection (like thread dumps or system metrics) across all instances of the application running on Cloud Foundry.
There are two actors handling the orchestration of the remote trigger actions: one on the client side, and the other on the application container (agent) side as explained in the following figure.

The application container will be configured to spawn off shell scripts (running in background) that is able to monitor for access modification timestamp of designated files.
This script kickoff is handled by the WebLogic Buildpack release step (that starts the application or its container).

|Dump Action    |         Script       |        Designated Target File
----------------|:--------------------:|---------------------------
|Heap         |    dumpHeapAgent.sh   |    /home/vcap/tmp/dumpHeap
|Stats        |    dumpStatsAgent.sh  |    /home/vcap/tmp/dumpStats
|Thread       |    dumpThreadAgent.sh |    /home/vcap/tmp/dumpThread


# Triggers

Using `cf files` or `cf curl`, users can access server side files from client side. This will update the access time of the target file.
The [trigger script](../resources/wls/monitoring/client/triggerDumps.sh) can be used to access specific target files for each trigger action.

```
$ ./triggerDumps.sh wls12c stats

Triggered stats dump on App: wls12c for instance: 0 by accessing filepath tmp/dumpStats under /home/vcap on application container

Finished triggering stats dumps for App: 'wls12c', across 1 instances

$ ./triggerDumps.sh wls12c thread

Triggered thread dump on App: wls12c for instance: 0 by accessing filepath tmp/dumpThread under /home/vcap on application container

Finished triggering thread dumps for App: 'wls12c', across 1 instances

```

The trigger script goes against each individual running application instance rather than the very first running instance as `cf files` does by default.

# Use of Monitoring Scripts with non-WebLogic Buildpack

Its possible to use the monitoring agent scripts with any Java Applications without using the WebLogic Buildpack.
If the target application is of type Java Web App (deployed as WAR), follow the steps to add trigger actions:
 * Copy the <a href=https://github.com/pivotal-cf/weblogic-buildpack/raw/master/resources/wls/monitoring/kickOffMonitoring.jsp> kickOffMonitoring.jsp </a> page into the Web Application top folder.
 * Copy the <a href=https://github.com/pivotal-cf/weblogic-buildpack/raw/master/resources/wls/monitoring/monitoring.jar> monitoring jar </a> file into the Web Application's WEB-INF/lib folder.
 * Recreate the Java Web Application `war` or `WAR` file with the two additions (jsp page and the jar library).
 * Push the updated application using `cf push` command to apply the changes.
 * Access the kickOffMonitoring.jsp page on the application which will kick start the monitoring agents.
 * Extract the bundled client trigger/capture scripts (within the monitoring.jar file) and use those to trigger actions or capture the dumps as needed.

Similar approach can also be used with Ruby or other language based applications to kick off the actual monitoring agent scripts execution from an application and then capture the data as needed.

# Application Container Process Tree

The process tree structure looks like following:
```
┬─bash───bash─┬─2*[bash───tee]
            │             └─startWebLogic.s───startWebLogic.s───java───35*[{java}]
            └─monitorAgents.s─┬─dumpHeapAgent.s───sleep
                              ├─dumpStatsAgent.───sleep
                              ├─dumpThreadAgent───sleep
                              └─sleep
```
The dumperAgent.sh script kicks of the monitorAgents.sh script to run in background and exits.
The monitorAgents.sh script kicks off the various agents (thread/heap/stats) and keeps checking to ensure the scripts continue to run.
Each of the scripts look for change in the access time of a designated target file after some pre-determined sleep interval.
On modification, they trigger specific actions (like sending signals or using specific tools to trigger data like jstack/jmap etc.).
They also re-touch the file so any subsequent read access will change the access time as well as note time of their action so they can know there was an external trigger action.
Some actions can generate outputs in specific files that get saved under /home/vcap/dumps folder with day as a sub-folder

# Generated files:
```
root@17ot17mh2rs:/home/vcap# ls -lrt /home/vcap/dumps/
total 4
drwx------ 2 vcap vcap 4096 Jun  3 20:18 06_03_14
root@17ot17mh2rs:/home/vcap# ls -lrt /home/vcap/dumps/06_03_14/
total 93600
-rw------- 1 vcap vcap    10856 Jun  3 20:15 stats.wls12c-0.06_03_14.20_15_08.txt
-rw------- 1 vcap vcap    89735 Jun  3 20:16 threadDump.wls12c-0.103.06_03_14.20_15_39.txt
-rw------- 1 vcap vcap 95737852 Jun  3 20:18 wls12c-0.103.06_03_14.20_18_09.hprof
```


The script can create the designated target file (using unix touch call) and keep doing stat operation to check the last access time in a forever loop. On detecting some recent access of the target file (check for the timestamp difference since last touch by the script ), it can then kick off the relevant actions (like dumping threads or gathering system stats/metrics) and re-touch the file and save the most recent update time.

- See more at: http://blog.gopivotal.com/cloud-foundry-pivotal/products/remote-triggers-for-applications-on-cloud-foundry#sthash.rbPivI7d.dpuf

The WebLogic Buildpack bundles the background scripts as part of the application bits so they can pick the trigger signals sent via cf files or access of a designated target file to kick off the data collection.
The sample scripts are packaged under the resources/wls/monitoring folder.


# Capture of data


Using `cf files` or `cf curl`, users can access/download the generated server side files from client side.
The [capture script](../resources/wls/monitoring/client/captureDumps.sh) can be used to download the generated files by specifying the path and name of the files.

```
./captureDumps.sh wls12c
Listing contents of file or directory for App: wls12c , for instance: 0
 (fetching from /home/vcap/dumps/ )

06_03_14/                                    -



./captureDumps.sh wls12c 06_03_14
InstanceId is 0
Listing contents of file or directory for App: wls12c , for instance: 0
 (fetching from /home/vcap/dumps/06_03_14 )

stats.wls12c-0.06_03_14.20_15_08.txt      10.6K
threadDump.wls12c-0.103.06_03_14.20_15_39.txt      87.6K

Finished capture of directory/file contents for App: 'wls12c', with # of running instances: 1


./captureDumps.sh wls12c 06_03_14/threadDump.wls12c-0.103.06_03_14.20_15_39.txt
\#\#\#   Saved threadDump.wls12c-0.103.06_03_14.20_15_39.txt for instance: 0 of app: wls12c

Finished capture of directory/file contents for App: 'wls12c', with # of running instances: 1

```

The capture script goes against each individual running application instance and it might report error for some files as the files are generated with instance id.

Its also possible to use wildcard character with the captureDump script so one can request for thread*, or heap* or stats* and get the most recent (last file matching the given pattern) to be retrieved from the different instances that match the given pattern and path.

```
hammerkop:workspace sparameswaran$ ./captureDumps.sh wls12c 06_11_14/threadDump.wl*
Checking Instance Index: 0 of app: wls12c
Complete url: /v2/apps/ed16145c-81d3-4059-ab0e-c15fcf9d250f/instances/0/files/dumps/06_11_14/threadDump.wls12c-0.108.06_11_14.01_55_23.txt
Saved curl output in threadDump.wls12c-0.108.06_11_14.01_55_23.txt.tmp...
CompleteFilePath: 06_11_14/threadDump.wl*
###   Saved threadDump.wls12c-0.108.06_11_14.01_55_23.txt for instance: 0 of app: wls12c

Checking Instance Index: 1 of app: wls12c
Complete url: /v2/apps/ed16145c-81d3-4059-ab0e-c15fcf9d250f/instances/1/files/dumps/06_11_14/threadDump.wls12c-1.108.06_11_14.01_55_23.txt
Saved curl output in threadDump.wls12c-1.108.06_11_14.01_55_23.txt.tmp...
CompleteFilePath: 06_11_14/threadDump.wl*
###   Saved threadDump.wls12c-1.108.06_11_14.01_55_23.txt for instance: 1 of app: wls12c

Finished capture of directory/file contents for App: 'wls12c', with # of running instances: 2

hammerkop:workspace sparameswaran$ ./captureDumps.sh wls12c 06_11_14/stats.wls12c*
Checking Instance Index: 0 of app: wls12c
Complete url: /v2/apps/ed16145c-81d3-4059-ab0e-c15fcf9d250f/instances/0/files/dumps/06_11_14/stats.wls12c-0.06_11_14.02_01_20.txt
Saved curl output in stats.wls12c-0.06_11_14.02_01_20.txt.tmp...
CompleteFilePath: 06_11_14/stats.wls12c*
###   Saved stats.wls12c-0.06_11_14.02_01_20.txt for instance: 0 of app: wls12c

Checking Instance Index: 1 of app: wls12c
Complete url: /v2/apps/ed16145c-81d3-4059-ab0e-c15fcf9d250f/instances/1/files/dumps/06_11_14/stats.wls12c-1.06_11_14.02_01_20.txt
Saved curl output in stats.wls12c-1.06_11_14.02_01_20.txt.tmp...
CompleteFilePath: 06_11_14/stats.wls12c*
###   Saved stats.wls12c-1.06_11_14.02_01_20.txt for instance: 1 of app: wls12c

Finished capture of directory/file contents for App: 'wls12c', with # of running instances: 2
```

#Note:
Heap Dumps generated for Java Applications can be downloaded remotely using the capture script similar to the thread dumps.
cf curl cli version prior to 6.1.2 adds a newline character as part of the final output, the heap dump can appear corrupted when reading it with Java Heap Analyzers like Eclipse MAT tool. So, the script automatically stripts off the last byte from the saved output which can take sometime to complete.
Version 6.1.2 and newer allows --output option to save the output as a file and does not require this stripping of the last unneeded byte.

# Limitations of Openjdk

* The default Java Buildpack uses Openjdk rather than Oracle HotSpot Jre. Unfortunately, the openjdk version of the jvm does not contain jmap or jstack utility
  * No heap dump generation is possible due to absence of jmap.
  * The thread dumps cannot be redirected to a separate log file in the absence of jstack. One would have to use kill -3 signal to trigger thread dumps which
  * Use cf logs after issuing thread dumps or cf files to retreive the contents of the stdout.log file that would have the generated thread dumps.

# Default Actions

The scripts bundled with the buildpack are generic enough that it can also be used by Ruby Applications as well as non-WebLogic Server targetted Java Applications.

* Java Applications would use jstack for thread dump generation. Five dumps would be collected at 5 second intervals on each trigger action.
  It would use jmap to generate heap dumps.
* Oracle HotSpot Jre is recommended for usage with the buildpack, as the Openjdk version of the jvm does not contain jmap or jstack utilities.
* Ruby Applications would require x-ray gem to capture thread dumps. There is no jmap equivalent to generate heap dumps for Ruby.
* The Stats script collections top, vmstat, mpstat, iostat, ps and environment log information as part of the dumpStats action.

