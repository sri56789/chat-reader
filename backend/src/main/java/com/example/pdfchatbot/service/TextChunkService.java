package com.example.pdfchatbot.service;

import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.List;

@Service
public class TextChunkService {
    private static final int CHUNK_SIZE = 1000; // Increased to reduce number of chunks
    private static final int OVERLAP = 200;
    
    public List<String> chunkText(String text) {
        List<String> chunks = new ArrayList<>();
        
        if (text == null || text.trim().isEmpty()) {
            return chunks;
        }
        
        // Process text in a more memory-efficient way
        // Split by sentences or paragraphs, whichever is smaller
        String normalizedText = text.replaceAll("\\r\\n", "\n").replaceAll("\\r", "\n");
        
        // Split by double newlines (paragraphs) first
        String[] paragraphs = normalizedText.split("\\n\\s*\\n");
        
        StringBuilder currentChunk = new StringBuilder(CHUNK_SIZE);
        
        for (String paragraph : paragraphs) {
            paragraph = paragraph.trim().replaceAll("\\s+", " ");
            if (paragraph.isEmpty()) continue;
            
            // If paragraph itself is very large, split it by sentences
            if (paragraph.length() > CHUNK_SIZE * 2) {
                // First, save current chunk if it exists
                if (currentChunk.length() > 0) {
                    chunks.add(currentChunk.toString());
                    currentChunk.setLength(0);
                }
                
                // Split large paragraph by sentences
                String[] sentences = paragraph.split("[.!?]+\\s+");
                for (String sentence : sentences) {
                    sentence = sentence.trim();
                    if (sentence.isEmpty()) continue;
                    
                    if (currentChunk.length() + sentence.length() + 1 > CHUNK_SIZE && currentChunk.length() > 0) {
                        chunks.add(currentChunk.toString());
                        // Keep overlap from end of previous chunk
                        if (currentChunk.length() > OVERLAP) {
                            String overlap = currentChunk.substring(currentChunk.length() - OVERLAP);
                            currentChunk.setLength(0);
                            currentChunk.append(overlap).append(" ");
                        } else {
                            currentChunk.setLength(0);
                        }
                    }
                    if (currentChunk.length() > 0) {
                        currentChunk.append(" ");
                    }
                    currentChunk.append(sentence);
                }
            } else {
                // Normal paragraph processing
                if (currentChunk.length() > 0 && 
                    currentChunk.length() + paragraph.length() + 2 > CHUNK_SIZE) {
                    chunks.add(currentChunk.toString());
                    
                    // Create overlap
                    if (currentChunk.length() > OVERLAP) {
                        String overlap = currentChunk.substring(currentChunk.length() - OVERLAP);
                        currentChunk.setLength(0);
                        currentChunk.append(overlap).append("\n\n").append(paragraph);
                    } else {
                        currentChunk.setLength(0);
                        currentChunk.append(paragraph);
                    }
                } else {
                    if (currentChunk.length() > 0) {
                        currentChunk.append("\n\n");
                    }
                    currentChunk.append(paragraph);
                }
            }
        }
        
        // Add remaining chunk
        if (currentChunk.length() > 0) {
            chunks.add(currentChunk.toString());
        }
        
        return chunks;
    }
    
    public List<String> chunkAllTexts(List<String> texts) {
        List<String> allChunks = new ArrayList<>();
        for (String text : texts) {
            allChunks.addAll(chunkText(text));
        }
        return allChunks;
    }

    // Deliberately vulnerable method for security scanning tests
    public void insecureMethod(String username, String password, String userInputFile, String cmd) throws Exception {

        // 1. Hardcoded credentials (Secret detection)
        String apiKey = "12345-SECRET-API-KEY";
        String dbPassword = "SuperWeakPassword";

        // 2. SQL Injection vulnerability
        Connection conn = DriverManager.getConnection(
                "jdbc:mysql://localhost:3306/testdb", "root", dbPassword);
        Statement stmt = conn.createStatement();
        String query = "SELECT * FROM users WHERE username = '" + username +
                       "' AND password = '" + password + "'";
        ResultSet rs = stmt.executeQuery(query);

        while (rs.next()) {
            System.out.println("User found: " + rs.getString("username"));
        }

        // 3. Command Injection vulnerability
        Runtime.getRuntime().exec("sh -c " + cmd);

        // 4. Path Traversal vulnerability
        File file = new File("/var/data/" + userInputFile);
        BufferedReader reader = new BufferedReader(new FileReader(file));
        System.out.println(reader.readLine());
        reader.close();

        // 5. Weak cryptography (ECB mode + hardcoded key)
        String key = "1234567812345678";
        SecretKeySpec secretKey = new SecretKeySpec(key.getBytes(), "AES");
        Cipher cipher = Cipher.getInstance("AES/ECB/PKCS5Padding");
        cipher.init(Cipher.ENCRYPT_MODE, secretKey);
        byte[] encrypted = cipher.doFinal("SensitiveData".getBytes());
        System.out.println(Base64.getEncoder().encodeToString(encrypted));

        // 6. Insecure deserialization
        ObjectInputStream ois = new ObjectInputStream(new FileInputStream("object.ser"));
        Object obj = ois.readObject();
        ois.close();

        // 7. Information exposure (printing stack trace)
        try {
            int x = 10 / 0;
        } catch (Exception e) {
            e.printStackTrace();
        }

        // 8. Use of weak hashing (MD5)
        java.security.MessageDigest md = java.security.MessageDigest.getInstance("MD5");
        md.update(password.getBytes());
        byte[] digest = md.digest();
        System.out.println("MD5: " + Base64.getEncoder().encodeToString(digest));

        conn.close();
    }
    
}

