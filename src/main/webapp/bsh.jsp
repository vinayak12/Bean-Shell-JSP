<%--

 NOT the usual license stuff, SO PLEASE READ:

 This page gives any user who has access to it the ability to execute arbitrary Beanshell
 commands in your server JVM. Even though a primitive 'allowed' list is built-in to control
 which hosts have access (by default only the localhost, see below), you probably still
 DO NOT WANT TO KEEP THIS FILE DEPLOYED IN ANY PRODUCTION SERVER.

 ------------------------------------------------------------------------------------------

 Now the usual license stuff (MIT License):

 Copyright (c) 2006 digiZen Studio, LLC 

 Permission is hereby granted, free of charge, to any person obtaining a copy of this
 software and associated documentation files (the "Software"), to deal in the Software
 without restriction, including without limitation the rights to use, copy, modify, merge,
 publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons
 to whom the Software is furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all copies or
 substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
 INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
 PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
 FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
 OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 DEALINGS IN THE SOFTWARE.

--%>
<%@ page import="bsh.*,java.util.*,java.io.*"%>
<%!

/******** Config section begins. **********/
// Edit this list to control who gets access to this page. Does NOT support wildcards.
final String[] _allowed = new String[] {
  "127.0.0.1",
  "localhost"
};
/********* Config section ends. *************/

final static String version = "0.8.2";

final static int HISTORY_ITEM_ARRAY_LEN = 5;
final static int IDX_EXPR = 0;
final static int IDX_RESULT = 1;
final static int IDX_TIMESTAMP = 2;
final static int IDX_HAS_ERROR = 3;
final static int IDX_OUTPUT = 4;

final static String KEY_EXPR = "expr";
final static String KEY_SOURCE_FILE = "sourceFile";
final static String KEY_RESET = "reset";
final static String KEY_DOWNLOAD = "download";

final static String KEY_HISTORY = "bsh.history";
final static String KEY_INTERPRETER = "bsh.interpreter";

%><%  /* the "controller" */
if (shouldBoot(request, out)) {
  return;
}

if (request.getParameter(KEY_DOWNLOAD) != null) {
  onDownload(response, out, session);
  return;
}

boolean doReset = (request.getParameter(KEY_RESET) != null);
if (doReset) {
  onReset(session);
}

List history = getHistory(session);

boolean needToRunRC = false;
Interpreter intpr = (Interpreter)session.getAttribute(KEY_INTERPRETER);
if (intpr == null) {
  intpr = new Interpreter();
  session.setAttribute(KEY_INTERPRETER, intpr);
  intpr.set("application", application);
  intpr.set("session", session);
  intpr.set("gApplication", application);
  intpr.set("gSession", session);

  needToRunRC = true;
}

String sourceFile = request.getParameter(KEY_SOURCE_FILE);
String expr = request.getParameter(KEY_EXPR);
%>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">

<html>
<head>
  <title>Beanshell Web Console</title>
  <style type="text/css">
body {
  font-family: verdana, sans-serif;
  font-size: 100.0%;
}

a {
  text-decoration:none;
  font-weight: 700;
  font-size: 0.8em;
}

a:link, a:visited, a:active {
  color: #8f8f8f;
}

a:hover {
  color: #0f0f0f;
}

.content {
  position: relative;
  border: 1px solid #e3e3e3;
  padding: 0.3em;
}

.utils {
  display: block;
  margin-bottom: 0.3em;
}

.utils ul {
  margin: 0;
}

.utils ul li {
  display: inline;
  padding-left: 0.3em;
}

.formBlock {
  width: 60%;
}

.formBlock form {
  margin: 0;
}

label {
  display: block;
  font-size: 0.8em;
  margin-top: 0.2em;
}

textarea {
  display: block;
}

.outputBlock {
  display: block;
  border: 1px solid #c8c8c8;
  font-weight: 500;
  padding: 0.1em 0.2em;
  margin: 0.2em 0;
  width: 60%;
  min-height: 3em;
  overflow: auto;
}

.historyBlock {
  width: 100%;
}

.headline, caption {
  font-weight: 800;
  font-variant: small-caps;
  margin: 0.1em;
}

caption {
  padding-up: 0.8em;
  padding-bottom: 0.5em;
}

.history {
  width: 100%;
  border-collapse: collapse;
  margin-top: 0.8em;
  margin-bottom: 0.8em;
}

td {
  border: 1px solid #c8c8c8;
  padding: 0.1em 0.4em 0.1em 0.4em;
  font-size: 85%;
}

.tableHeader {
  background-color: #e8e8e8;
  color: #282828;
  font-weight: 600;
}

.evenRow {
  background-color: #fbfbfb;
}

.versionBlock {
  clear:both;
  font-size: 80%;
  font-style: italic;
}

.listPanel {
  position: absolute;
  top: 1.5em;
  height: 23em;
  width: 18%;
  border: 1px dotted #c8c8c8;
  overflow: auto;
}

#varPanel {
  right: 20%;
}

#methodPanel {
  right: 1%;
}

.listPanel p {
  margin: 0.2em 0.1em;
}

.listPanel ul {
  margin: 0.1em 0.1em;
  list-style-position: inside;
}

.listPanel ul li {
  padding-left: 0.1em;
}
  </style>
</head>
<body>
  <div class="content"> 
    <div class="utils">
      <ul>
        <li><a href="bsh.jsp?<%=KEY_RESET%>=1"><acronym title="Reset current bsh session.">Reset</acronym></a></li>
        <li><a href="bsh.jsp?<%=KEY_DOWNLOAD%>=1"><acronym title="Download the script accumulated in current bsh session.">Download Script</acronym></a></li>
        <li><a href="#formBlock"><acronym title="Go to the input form">Input</acronym></a></li>
      </ul>
    </div>

    <div class="resultBlock">
      <p class="headline">Output:</p>
      <div class="outputBlock">
    <%
      boolean hasError = false;
      FilteredJspWriter outBuff = new FilteredJspWriter(out);
      intpr.set("request", request);
      intpr.set("out", outBuff);
      intpr.set("gRequest", request);
      intpr.set("gOut", outBuff);

      String[] historyItem = null;
      if (needToRunRC) {
        String rcPath = application.getRealPath("/WEB-INF/.bshrc");
        if (new File(rcPath).exists()) {
          historyItem = runEval(intpr, rcPath, true);
        }
      }
      String scriptDir = (String)intpr.get("gScriptPath");
      if (scriptDir == null) {
        scriptDir = "/WEB-INF/scripts";
      }
      scriptDir = application.getRealPath(scriptDir);
      File scriptDirFile = new File(scriptDir);

      if (expr != null && !expr.trim().equals("")) {
        historyItem = runEval(intpr, expr, false);
      } else if (sourceFile != null && !sourceFile.trim().equals("")) {
        String sourceScriptPath = new File(scriptDirFile, sourceFile).getCanonicalPath();
        if (!sourceScriptPath.startsWith(scriptDir)) {
          throw new IllegalArgumentException("Attempted sourceScriptPath=" + sourceScriptPath);
        }
        historyItem = runEval(intpr, sourceScriptPath, true);
      }

      if (historyItem != null) {
        history.add(historyItem);
        hasError = historyItem[IDX_HAS_ERROR] != null;
      }
    %>
      </div>
    </div>

    <div class="formBlock"><a id="formBlock" name="formBlock" class="headline">Input</a>
      <form action="bsh.jsp" method="POST">
        <select name="<%=KEY_SOURCE_FILE%>">
          <option value="">Select a script file.</option>
          <%
          if (scriptDirFile.exists()) {
            List scripts = getAllScripts(scriptDirFile);
            for (Iterator iScript = scripts.iterator(); iScript.hasNext(); ) {
              String scriptPath = (String)iScript.next();
              String selected = "";
              if (scriptPath.equals(sourceFile)) {
                selected = "selected=\"selected\"";
              }
          %>
              <option value="<%= scriptPath %>" <%= selected %>><%= scriptPath %></option>
          <%}
          } %>
        </select>
        <label for="<%=KEY_EXPR%>">Or type commands here:</label>
        <textarea id="<%=KEY_EXPR%>" name="<%=KEY_EXPR%>" cols="60" rows="15"><%=hasError?expr:""%></textarea>
        <input type="submit" value="Run" accesskey="r" />
      </form>
    </div>

    <div class="historyBlock">
    <table class="history">
      <caption>History</caption>
      <tr class="tableHeader"><td>Expr</td><td>Result</td><td>Output</td><td>Time</td></tr>
      <%
      int counter = 0;
      for (Iterator i = history.iterator(); i.hasNext(); ) {
          counter++;
          String[] item = (String[])i.next();
          String rowStyle = "oddRow";
          if (counter % 2 == 0) {
            rowStyle = "evenRow";
          }
      %>
      <tr class="<%=rowStyle%>">
        <td><%=escapeXml(item[IDX_EXPR])%></td>
        <td><%=escapeXml(item[IDX_RESULT])%></td>
        <td><%=item[IDX_OUTPUT]%></td>
        <td><%=item[IDX_TIMESTAMP]%></td>
      </tr>
      <%}%>
    </table>
    </div>
  </div>
  <div id="varPanel" class="listPanel">
  <p class="headline">Variables:</p>
  <% String[] variables = (String[])intpr.get("this.variables");
     Arrays.sort(variables); %>
  <ul>
  <% for (int iVar = 0; iVar < variables.length; iVar++) { %>
    <li><%=variables[iVar]%></li>
  <%}%>
  </ul>
  </div>

  <div id="methodPanel" class="listPanel">
  <p class="headline">Methods:</p>
  <% String[] methods = (String[])intpr.get("this.methods");
     Arrays.sort(methods); %>
  <ul>
  <% for (int iVar = 0; iVar < methods.length; iVar++) { %>
    <li><%=methods[iVar]%></li>
  <%}%>
  </ul>
  </div>

  <div class="versionBlock">Version <%=version%></div>
</body>
</html>
<%!
private void onDownload(HttpServletResponse response, JspWriter out, HttpSession session) throws IOException {
  List history = getHistory(session);
  response.setContentType("text/plain");
  for (Iterator iItem = history.iterator(); iItem.hasNext(); ) {
    String[] item = (String[])iItem.next();
    // only print the commands that didn't cause an error.
    if (item[IDX_HAS_ERROR] == null) {
      out.println(item[IDX_EXPR]);
    }
  }
}

private void onReset(HttpSession session) {
  getHistory(session).clear();
  session.removeAttribute(KEY_HISTORY);
  session.removeAttribute(KEY_INTERPRETER);
}

private boolean shouldBoot(HttpServletRequest request, JspWriter out) throws IOException {
 /* String remoteHost = request.getRemoteHost();
  for (int i = 0; i < _allowed.length; i++) {
    if (_allowed[i].equalsIgnoreCase(remoteHost)) {
      return false;
    }
  }
  out.println("Your host name: <strong>" + remoteHost + "</strong> is not on the allowed list.");*/
  return false;
}

private List getHistory(HttpSession session) {
  List history = (List)session.getAttribute(KEY_HISTORY);
  if (history == null) {
    history = new ArrayList();
    session.setAttribute(KEY_HISTORY, history);
  }
  return history;
}

private String[] runEval(Interpreter intpr, String expr, boolean doSource) {
  System.out.println("About to " + (doSource?"source":"eval") + " " + expr);
  String result = null;
  boolean hasError = false;
  String errorTxt = null;
  try {
    Object resultObj = null;
    if (doSource) {
      resultObj = intpr.source(expr);
    } else {
      resultObj = intpr.eval(expr);
    }
    result = (resultObj != null) ? resultObj.toString() : "null";
  } catch (EvalError e) {
    try {
        intpr.set("gLastEvalError", e);
        if (intpr.get("gEvalErrorHandler") != null) {
            intpr.eval("gEvalErrorHandler.onError();");
        }
    } catch (EvalError e1) {
        System.out.println("EvalErrorHandler error: " + e1);
    }
    hasError = true;
    if (e instanceof ParseException) {
      errorTxt = e.toString();
    } else if (e instanceof TargetError) {
      errorTxt = e.toString();
    } else {
      errorTxt = e.getClass() + " on line " + e.getErrorLineNumber() + ": " + e.getErrorText();
    }
  } catch (IOException e) {
    hasError = true;
    errorTxt = "Unable to source script file " + expr + " due to: " + e.getMessage();
  }

  if (hasError) {
    result = errorTxt;
  }

  String[] historyItem = new String[HISTORY_ITEM_ARRAY_LEN];
  historyItem[IDX_EXPR] = expr;
  historyItem[IDX_RESULT] = result;
  historyItem[IDX_TIMESTAMP] = new Date().toString(); // the timestamp
  historyItem[IDX_HAS_ERROR] = hasError? "foo" : null; // whether this was an erroneous command.
  try {
    historyItem[IDX_OUTPUT] = ((FilteredJspWriter)intpr.get("gOut")).getContent();
  } catch (EvalError e) {
    e.printStackTrace();
  }

  return historyItem;
}

private List getAllScripts(File root) throws IOException {
  final String rootPath = root.getCanonicalPath();
  List scripts = new ArrayList();
  List dirs = new ArrayList();
  dirs.add(root);
  while (!dirs.isEmpty()) {
    File dir = (File)dirs.remove(0);
    File[] children = dir.listFiles();
    Arrays.sort(children);
    for (int iChild = 0; iChild < children.length; iChild++) {
      if (children[iChild].isDirectory()) {
        dirs.add(children[iChild]);
      } else if (children[iChild].getName().endsWith(".bsh")) {
        scripts.add(children[iChild].getCanonicalPath().substring(rootPath.length() + 1));
      }
    }
  }
  return scripts;
}

private String escapeXml(String str) {
  if (str == null) {
    return "null";
  }

  StringBuffer buff = new StringBuffer();
  for (int iChar = 0; iChar < str.length(); iChar++) {
    FilteredJspWriter.escapeChar(str.charAt(iChar), buff);
  }
  return buff.toString();
}

public static class FilteredJspWriter extends PrintWriter {
  private StringBuffer _buff = new StringBuffer();
  private int _lastFlushPos = 0;

  public FilteredJspWriter(Writer writer) {
      super(writer, true);
  }

  public void println() {
      write('\n');
      flush();
  }

  public void flush() {
      try {
          out.write(_buff.substring(_lastFlushPos));
          out.flush();
          _lastFlushPos = _buff.length();
      } catch (IOException e) {
          setError();
      }
  }

  public void write(int c) {
    escapeChar((char)c, _buff);
  }

  public void write(char buf[], int off, int len) {
    for (int iChar = off; iChar < off + len; iChar++) {
      escapeChar(buf[iChar], _buff);
    }
  }

  public void write(String s, int off, int len) {
    for (int iChar = off; iChar < off + len; iChar++) {
      escapeChar(s.charAt(iChar), _buff);
    }
  }

  public String getContent() {
    return _buff.toString();
  }

  public static void escapeChar(char c, StringBuffer buff) {
    switch (c) {
      case '<':
          buff.append("&lt;");
          break;
      case '>':
          buff.append("&gt;");
          break;
      case '&':
          buff.append("&amp;");
          break;
      case ' ':
          buff.append("&nbsp;");
          break;
      case '\t':
          buff.append("&nbsp;&nbsp;&nbsp;&nbsp;");
          break;
      case '\n':
          buff.append("<br />");
      default:
          buff.append(c);
          break;
    }
  }
}
%>
=======
<%--

 NOT the usual license stuff, SO PLEASE READ:

 This page gives any user who has access to it the ability to execute arbitrary Beanshell
 commands in your server JVM. Even though a primitive 'allowed' list is built-in to control
 which hosts have access (by default only the localhost, see below), you probably still
 DO NOT WANT TO KEEP THIS FILE DEPLOYED IN ANY PRODUCTION SERVER.

 ------------------------------------------------------------------------------------------

 Now the usual license stuff (MIT License):

 Copyright (c) 2006 digiZen Studio, LLC 

 Permission is hereby granted, free of charge, to any person obtaining a copy of this
 software and associated documentation files (the "Software"), to deal in the Software
 without restriction, including without limitation the rights to use, copy, modify, merge,
 publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons
 to whom the Software is furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all copies or
 substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
 INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
 PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
 FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
 OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 DEALINGS IN THE SOFTWARE.

--%>
<%@ page import="bsh.*,java.util.*,java.io.*"%>
<%!

/******** Config section begins. **********/
// Edit this list to control who gets access to this page. Does NOT support wildcards.
final String[] _allowed = new String[] {
  "127.0.0.1",
  "localhost"
};
/********* Config section ends. *************/

final static String version = "0.8.2";

final static int HISTORY_ITEM_ARRAY_LEN = 5;
final static int IDX_EXPR = 0;
final static int IDX_RESULT = 1;
final static int IDX_TIMESTAMP = 2;
final static int IDX_HAS_ERROR = 3;
final static int IDX_OUTPUT = 4;

final static String KEY_EXPR = "expr";
final static String KEY_SOURCE_FILE = "sourceFile";
final static String KEY_RESET = "reset";
final static String KEY_DOWNLOAD = "download";

final static String KEY_HISTORY = "bsh.history";
final static String KEY_INTERPRETER = "bsh.interpreter";

%><%  /* the "controller" */
if (shouldBoot(request, out)) {
  return;
}

if (request.getParameter(KEY_DOWNLOAD) != null) {
  onDownload(response, out, session);
  return;
}

boolean doReset = (request.getParameter(KEY_RESET) != null);
if (doReset) {
  onReset(session);
}

List history = getHistory(session);

boolean needToRunRC = false;
Interpreter intpr = (Interpreter)session.getAttribute(KEY_INTERPRETER);
if (intpr == null) {
  intpr = new Interpreter();
  session.setAttribute(KEY_INTERPRETER, intpr);
  intpr.set("application", application);
  intpr.set("session", session);
  intpr.set("gApplication", application);
  intpr.set("gSession", session);

  needToRunRC = true;
}

String sourceFile = request.getParameter(KEY_SOURCE_FILE);
String expr = request.getParameter(KEY_EXPR);
%>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">

<html>
<head>
  <title>Beanshell Web Console</title>
  <style type="text/css">
body {
  font-family: verdana, sans-serif;
  font-size: 100.0%;
}

a {
  text-decoration:none;
  font-weight: 700;
  font-size: 0.8em;
}

a:link, a:visited, a:active {
  color: #8f8f8f;
}

a:hover {
  color: #0f0f0f;
}

.content {
  position: relative;
  border: 1px solid #e3e3e3;
  padding: 0.3em;
}

.utils {
  display: block;
  margin-bottom: 0.3em;
}

.utils ul {
  margin: 0;
}

.utils ul li {
  display: inline;
  padding-left: 0.3em;
}

.formBlock {
  width: 60%;
}

.formBlock form {
  margin: 0;
}

label {
  display: block;
  font-size: 0.8em;
  margin-top: 0.2em;
}

textarea {
  display: block;
}

.outputBlock {
  display: block;
  border: 1px solid #c8c8c8;
  font-weight: 500;
  padding: 0.1em 0.2em;
  margin: 0.2em 0;
  width: 60%;
  min-height: 3em;
  overflow: auto;
}

.historyBlock {
  width: 100%;
}

.headline, caption {
  font-weight: 800;
  font-variant: small-caps;
  margin: 0.1em;
}

caption {
  padding-up: 0.8em;
  padding-bottom: 0.5em;
}

.history {
  width: 100%;
  border-collapse: collapse;
  margin-top: 0.8em;
  margin-bottom: 0.8em;
}

td {
  border: 1px solid #c8c8c8;
  padding: 0.1em 0.4em 0.1em 0.4em;
  font-size: 85%;
}

.tableHeader {
  background-color: #e8e8e8;
  color: #282828;
  font-weight: 600;
}

.evenRow {
  background-color: #fbfbfb;
}

.versionBlock {
  clear:both;
  font-size: 80%;
  font-style: italic;
}

.listPanel {
  position: absolute;
  top: 1.5em;
  height: 23em;
  width: 18%;
  border: 1px dotted #c8c8c8;
  overflow: auto;
}

#varPanel {
  right: 20%;
}

#methodPanel {
  right: 1%;
}

.listPanel p {
  margin: 0.2em 0.1em;
}

.listPanel ul {
  margin: 0.1em 0.1em;
  list-style-position: inside;
}

.listPanel ul li {
  padding-left: 0.1em;
}
  </style>
</head>
<body>
  <div class="content"> 
    <div class="utils">
      <ul>
        <li><a href="bsh.jsp?<%=KEY_RESET%>=1"><acronym title="Reset current bsh session.">Reset</acronym></a></li>
        <li><a href="bsh.jsp?<%=KEY_DOWNLOAD%>=1"><acronym title="Download the script accumulated in current bsh session.">Download Script</acronym></a></li>
        <li><a href="#formBlock"><acronym title="Go to the input form">Input</acronym></a></li>
      </ul>
    </div>

    <div class="resultBlock">
      <p class="headline">Output:</p>
      <div class="outputBlock">
    <%
      boolean hasError = false;
      FilteredJspWriter outBuff = new FilteredJspWriter(out);
      intpr.set("request", request);
      intpr.set("out", outBuff);
      intpr.set("gRequest", request);
      intpr.set("gOut", outBuff);

      String[] historyItem = null;
      if (needToRunRC) {
        String rcPath = application.getRealPath("/WEB-INF/.bshrc");
        if (new File(rcPath).exists()) {
          historyItem = runEval(intpr, rcPath, true);
        }
      }
      String scriptDir = (String)intpr.get("gScriptPath");
      if (scriptDir == null) {
        scriptDir = "/WEB-INF/scripts";
      }
      scriptDir = application.getRealPath(scriptDir);
      File scriptDirFile = new File(scriptDir);

      if (expr != null && !expr.trim().equals("")) {
        historyItem = runEval(intpr, expr, false);
      } else if (sourceFile != null && !sourceFile.trim().equals("")) {
        String sourceScriptPath = new File(scriptDirFile, sourceFile).getCanonicalPath();
        if (!sourceScriptPath.startsWith(scriptDir)) {
          throw new IllegalArgumentException("Attempted sourceScriptPath=" + sourceScriptPath);
        }
        historyItem = runEval(intpr, sourceScriptPath, true);
      }

      if (historyItem != null) {
        history.add(historyItem);
        hasError = historyItem[IDX_HAS_ERROR] != null;
      }
    %>
      </div>
    </div>

    <div class="formBlock"><a id="formBlock" name="formBlock" class="headline">Input</a>
      <form action="bsh.jsp" method="POST">
        <select name="<%=KEY_SOURCE_FILE%>">
          <option value="">Select a script file.</option>
          <%
          if (scriptDirFile.exists()) {
            List scripts = getAllScripts(scriptDirFile);
            for (Iterator iScript = scripts.iterator(); iScript.hasNext(); ) {
              String scriptPath = (String)iScript.next();
              String selected = "";
              if (scriptPath.equals(sourceFile)) {
                selected = "selected=\"selected\"";
              }
          %>
              <option value="<%= scriptPath %>" <%= selected %>><%= scriptPath %></option>
          <%}
          } %>
        </select>
        <label for="<%=KEY_EXPR%>">Or type commands here:</label>
        <textarea id="<%=KEY_EXPR%>" name="<%=KEY_EXPR%>" cols="60" rows="15"><%=hasError?expr:""%></textarea>
        <input type="submit" value="Run" accesskey="r" />
      </form>
    </div>

    <div class="historyBlock">
    <table class="history">
      <caption>History</caption>
      <tr class="tableHeader"><td>Expr</td><td>Result</td><td>Output</td><td>Time</td></tr>
      <%
      int counter = 0;
      for (Iterator i = history.iterator(); i.hasNext(); ) {
          counter++;
          String[] item = (String[])i.next();
          String rowStyle = "oddRow";
          if (counter % 2 == 0) {
            rowStyle = "evenRow";
          }
      %>
      <tr class="<%=rowStyle%>">
        <td><%=escapeXml(item[IDX_EXPR])%></td>
        <td><%=escapeXml(item[IDX_RESULT])%></td>
        <td><%=item[IDX_OUTPUT]%></td>
        <td><%=item[IDX_TIMESTAMP]%></td>
      </tr>
      <%}%>
    </table>
    </div>
  </div>
  <div id="varPanel" class="listPanel">
  <p class="headline">Variables:</p>
  <% String[] variables = (String[])intpr.get("this.variables");
     Arrays.sort(variables); %>
  <ul>
  <% for (int iVar = 0; iVar < variables.length; iVar++) { %>
    <li><%=variables[iVar]%></li>
  <%}%>
  </ul>
  </div>

  <div id="methodPanel" class="listPanel">
  <p class="headline">Methods:</p>
  <% String[] methods = (String[])intpr.get("this.methods");
     Arrays.sort(methods); %>
  <ul>
  <% for (int iVar = 0; iVar < methods.length; iVar++) { %>
    <li><%=methods[iVar]%></li>
  <%}%>
  </ul>
  </div>

  <div class="versionBlock">Version <%=version%></div>
</body>
</html>
<%!
private void onDownload(HttpServletResponse response, JspWriter out, HttpSession session) throws IOException {
  List history = getHistory(session);
  response.setContentType("text/plain");
  for (Iterator iItem = history.iterator(); iItem.hasNext(); ) {
    String[] item = (String[])iItem.next();
    // only print the commands that didn't cause an error.
    if (item[IDX_HAS_ERROR] == null) {
      out.println(item[IDX_EXPR]);
    }
  }
}

private void onReset(HttpSession session) {
  getHistory(session).clear();
  session.removeAttribute(KEY_HISTORY);
  session.removeAttribute(KEY_INTERPRETER);
}

private boolean shouldBoot(HttpServletRequest request, JspWriter out) throws IOException {
 /* String remoteHost = request.getRemoteHost();
  for (int i = 0; i < _allowed.length; i++) {
    if (_allowed[i].equalsIgnoreCase(remoteHost)) {
      return false;
    }
  }
  out.println("Your host name: <strong>" + remoteHost + "</strong> is not on the allowed list.");*/
  return false;
}

private List getHistory(HttpSession session) {
  List history = (List)session.getAttribute(KEY_HISTORY);
  if (history == null) {
    history = new ArrayList();
    session.setAttribute(KEY_HISTORY, history);
  }
  return history;
}

private String[] runEval(Interpreter intpr, String expr, boolean doSource) {
  System.out.println("About to " + (doSource?"source":"eval") + " " + expr);
  String result = null;
  boolean hasError = false;
  String errorTxt = null;
  try {
    Object resultObj = null;
    if (doSource) {
      resultObj = intpr.source(expr);
    } else {
      resultObj = intpr.eval(expr);
    }
    result = (resultObj != null) ? resultObj.toString() : "null";
  } catch (EvalError e) {
    try {
        intpr.set("gLastEvalError", e);
        if (intpr.get("gEvalErrorHandler") != null) {
            intpr.eval("gEvalErrorHandler.onError();");
        }
    } catch (EvalError e1) {
        System.out.println("EvalErrorHandler error: " + e1);
    }
    hasError = true;
    if (e instanceof ParseException) {
      errorTxt = e.toString();
    } else if (e instanceof TargetError) {
      errorTxt = e.toString();
    } else {
      errorTxt = e.getClass() + " on line " + e.getErrorLineNumber() + ": " + e.getErrorText();
    }
  } catch (IOException e) {
    hasError = true;
    errorTxt = "Unable to source script file " + expr + " due to: " + e.getMessage();
  }

  if (hasError) {
    result = errorTxt;
  }

  String[] historyItem = new String[HISTORY_ITEM_ARRAY_LEN];
  historyItem[IDX_EXPR] = expr;
  historyItem[IDX_RESULT] = result;
  historyItem[IDX_TIMESTAMP] = new Date().toString(); // the timestamp
  historyItem[IDX_HAS_ERROR] = hasError? "foo" : null; // whether this was an erroneous command.
  try {
    historyItem[IDX_OUTPUT] = ((FilteredJspWriter)intpr.get("gOut")).getContent();
  } catch (EvalError e) {
    e.printStackTrace();
  }

  return historyItem;
}

private List getAllScripts(File root) throws IOException {
  final String rootPath = root.getCanonicalPath();
  List scripts = new ArrayList();
  List dirs = new ArrayList();
  dirs.add(root);
  while (!dirs.isEmpty()) {
    File dir = (File)dirs.remove(0);
    File[] children = dir.listFiles();
    Arrays.sort(children);
    for (int iChild = 0; iChild < children.length; iChild++) {
      if (children[iChild].isDirectory()) {
        dirs.add(children[iChild]);
      } else if (children[iChild].getName().endsWith(".bsh")) {
        scripts.add(children[iChild].getCanonicalPath().substring(rootPath.length() + 1));
      }
    }
  }
  return scripts;
}

private String escapeXml(String str) {
  if (str == null) {
    return "null";
  }

  StringBuffer buff = new StringBuffer();
  for (int iChar = 0; iChar < str.length(); iChar++) {
    FilteredJspWriter.escapeChar(str.charAt(iChar), buff);
  }
  return buff.toString();
}

public static class FilteredJspWriter extends PrintWriter {
  private StringBuffer _buff = new StringBuffer();
  private int _lastFlushPos = 0;

  public FilteredJspWriter(Writer writer) {
      super(writer, true);
  }

  public void println() {
      write('\n');
      flush();
  }

  public void flush() {
      try {
          out.write(_buff.substring(_lastFlushPos));
          out.flush();
          _lastFlushPos = _buff.length();
      } catch (IOException e) {
          setError();
      }
  }

  public void write(int c) {
    escapeChar((char)c, _buff);
  }

  public void write(char buf[], int off, int len) {
    for (int iChar = off; iChar < off + len; iChar++) {
      escapeChar(buf[iChar], _buff);
    }
  }

  public void write(String s, int off, int len) {
    for (int iChar = off; iChar < off + len; iChar++) {
      escapeChar(s.charAt(iChar), _buff);
    }
  }

  public String getContent() {
    return _buff.toString();
  }

  public static void escapeChar(char c, StringBuffer buff) {
    switch (c) {
      case '<':
          buff.append("&lt;");
          break;
      case '>':
          buff.append("&gt;");
          break;
      case '&':
          buff.append("&amp;");
          break;
      case ' ':
          buff.append("&nbsp;");
          break;
      case '\t':
          buff.append("&nbsp;&nbsp;&nbsp;&nbsp;");
          break;
      case '\n':
          buff.append("<br />");
      default:
          buff.append(c);
          break;
    }
  }
}
%>
