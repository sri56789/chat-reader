import java.sql.*;
import java.io.*;

public class TestVuln {

    public static void main(String[] args) throws Exception {

        String user = args[0];

        // SQL Injection (almost always detected)
        Connection conn = DriverManager.getConnection("jdbc:mysql://localhost/test", "root", "root");
        Statement stmt = conn.createStatement();
        ResultSet rs = stmt.executeQuery("SELECT * FROM users WHERE name = '" + user + "'");

        // Command injection
        Runtime.getRuntime().exec(user);

        // Path traversal
        File f = new File("/tmp/" + user);
        BufferedReader br = new BufferedReader(new FileReader(f));
        System.out.println(br.readLine());
    }
}
