package codeql;

import java.sql.*;
import javax.servlet.http.HttpServletRequest;

public class TestCodeQL {

    public void vulnerable(HttpServletRequest request) throws Exception {

        String user = request.getParameter("user");

        Connection conn = DriverManager.getConnection(
                "jdbc:mysql://localhost:3306/testdb", "root", "root");

        Statement stmt = conn.createStatement();
        ResultSet rs = stmt.executeQuery(
                "SELECT * FROM users WHERE name = '" + user + "'");

        while (rs.next()) {
            System.out.println(rs.getString("name"));
        }

        Runtime.getRuntime().exec(user);
    }
}
