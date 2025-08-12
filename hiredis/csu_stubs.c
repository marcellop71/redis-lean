// Stub implementations for missing libc CSU functions
// These are normally provided by glibc but are missing when using lld

void __libc_csu_init(int argc, char **argv, char **envp) {
    // This function normally calls global constructors
    // For a simple case, we can provide an empty implementation
}

void __libc_csu_fini(void) {
    // This function normally calls global destructors  
    // For a simple case, we can provide an empty implementation
}
