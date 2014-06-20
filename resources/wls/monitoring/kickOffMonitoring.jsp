<%
   out.println("Going to kick off monitoring...");
   Runtime rt = Runtime.getRuntime();

   //String deployed_app_dir=new java.io.File(application.getRealPath(request.getRequestURI())).getParent().replace('\\', '/');
   //String jspFilePath = request.getServletContext().getRealPath(request.getRequestURI()).replace('\\', '/');
   //String absPath = jspFilePath.substring(0, jspFilePath.lastIndexOf("/"));
   String jspFilePath = request.getServletContext().getRealPath("/").replace('\\', '/');

   //out.println("requestUri: " + request.getRequestURI());
   //out.println("jspFilePath: " + jspFilePath);
   //out.println("absPath:  " + absPath);

   String deployed_app_dir = jspFilePath;
   String target_dir="/tmp/vcap/";
   StringBuffer sbuf = new StringBuffer();
   sbuf.append("mkdir " + target_dir + "\n ");
   sbuf.append("cp " + deployed_app_dir + "/WEB-INF/lib/monitoring.jar " + target_dir +"\n ");
   sbuf.append("cd " + target_dir + "\n ");
   sbuf.append("/usr/bin/unzip monitoring.jar\n ");
   sbuf.append("cd " + target_dir + "/monitoring/agent\n");
   sbuf.append("chmod +x *\n");
   sbuf.append("sh ß./dumperAgent.sh\n");
   out.println("Complete command: " + sbuf.toString());
   try {
     java.io.PrintWriter pout = new java.io.PrintWriter("/tmp/kickOffMonitor.sh");
     pout.print(sbuf.toString());
     pout.flush();
     pout.close();
   } catch(Exception e) {
     e.printStackTrace();
   }

   java.util.List<String> commands = new java.util.ArrayList<String>();
   commands.add("/bin/sh");
   commands.add("/tmp/kickOffMonitor.sh");
   //out.println("Complete Command: " + commands);
   ProcessBuilder procBuilder = new ProcessBuilder(commands);
   procBuilder.start();
%>
