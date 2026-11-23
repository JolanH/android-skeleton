package com.example.skeleton.domain

/** Example of pure, Android-free domain logic: the domain package carries the strictest coverage floor. */
object Greeter {
    fun greeting(name: String): String {
        val trimmed = name.trim()
        return if (trimmed.isEmpty()) "Hello!" else "Hello, $trimmed!"
    }
}
