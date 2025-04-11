package com.example.demo.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class HomeController {
    
    @GetMapping("/")
    public String home() {
        return "Welcome to Spring Demo!";
    }

    @GetMapping("/health")
    public String health() {
        return "UP";
    }
}
