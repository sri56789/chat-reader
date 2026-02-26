package codeql;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.Statement;
import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;

public class TestCodeQL {

    // Method with multiple CodeQL-detectable vulnerabilities
    public static void vulnerable(String userInput) throws Exception {

        // ---- SQL Injection (HIGH confidence detection)
        Connection conn = DriverManager.getConnection(
                "jdbc:mysql://localhost:3306/testdb", "root", "root");

        Statement stmt = conn.createStatement();
        String query = "SELECT * FROM users WHERE name = '" + userInput + "'";
        ResultSet rs = stmt.executeQuery(query);

        while (rs.next()) {
            System.out.println(rs.getString("name"));
        }

        // ---- Command Injection (HIGH confidence detection)
        Runtime.getRuntime().exec(userInput);

        // ---- Path Traversal (detected)
        File file = new File("/tmp/" + userInput);
        BufferedReader br = new BufferedReader(new FileReader(file));
        System.out.println(br.readLine());
        br.close();

        conn.close();
    }

    // Entry point so CodeQL considers it reachable
    public static void main(String[] args) throws Exception {
        String input = args.length > 0 ? args[0] : "test";
        vulnerable(input);
    }
}
