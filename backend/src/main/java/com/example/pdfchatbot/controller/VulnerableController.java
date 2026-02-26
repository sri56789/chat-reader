package com.example.pdfchatbot;

import org.springframework.web.bind.annotation.*;
import java.sql.*;
import java.io.*;

@RestController
@RequestMapping("/test")
public class VulnerableController {

    // 🚨 SQL Injection + Command Injection + Path Traversal
    @GetMapping("/vuln")
    public String vulnerable(@RequestParam String input) throws Exception {

        // ========== SQL Injection (CodeQL HIGH alert) ==========
        Connection conn = DriverManager.getConnection(
                "jdbc:mysql://localhost:3306/testdb", "root", "root");

        Statement stmt = conn.createStatement();
        ResultSet rs = stmt.executeQuery(
                "SELECT * FROM users WHERE name = '" + input + "'");

        while (rs.next()) {
            System.out.println(rs.getString("name"));
        }

        // ========== Command Injection (HIGH alert) ==========
        Runtime.getRuntime().exec(input);

        // ========== Path Traversal ==========
        File file = new File("/tmp/" + input);
        if(file.exists()){
            BufferedReader br = new BufferedReader(new FileReader(file));
            System.out.println(br.readLine());
            br.close();
        }

        conn.close();
        return "done";
    }
}
