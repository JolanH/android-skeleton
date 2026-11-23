package com.example.skeleton.domain

import org.junit.Assert.assertEquals
import org.junit.Test

class GreeterTest {
    @Test
    fun `greets by name`() {
        assertEquals("Hello, Ada!", Greeter.greeting("Ada"))
    }

    @Test
    fun `trims the name`() {
        assertEquals("Hello, Ada!", Greeter.greeting("  Ada "))
    }

    @Test
    fun `greets generically when the name is blank`() {
        assertEquals("Hello!", Greeter.greeting("   "))
    }
}
