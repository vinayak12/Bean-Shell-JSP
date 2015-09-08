# Bean-Shell-JSP

It a WEB based REPL(Read–eval–print loop) tool for JAVA based on Bean Shell and JSP.

Demo http://bsh-vinayak.rhcloud.com/bsh.jsp

Past below code in the Demo App

public static void fibonacci(int n) { 
       if (n == 0) { 
           gOut.println("0"); 
       } else if (n == 1) { 
           gOut.println("0 1"); 
       } else { 
           System.out.print("0 1 "); 
           int a = 0; 
           int b = 1; 
           for (int i = 1; i < n; i++) { 
               int nextNumber = a + b; 
               gOut.print(nextNumber + " "); 
               a = b; 
               b = nextNumber; 
           } 
       } 
   }
   
fibonacci(10);
