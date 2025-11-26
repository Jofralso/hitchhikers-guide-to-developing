/*
 * hello.c - Simple Hello World for BeaglePlay
 * 
 * DON'T PANIC - This is your first cross-compiled program!
 * 
 * The Guide says: "This program does nothing more remarkable than saying hello,
 * but it does it on a completely different architecture than the one it was 
 * compiled on. This is a bit like teaching a Vogon to recite poetry - technically
 * possible, but requires the right tools."
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/utsname.h>

void print_system_info(void)
{
    struct utsname sys_info;
    
    if (uname(&sys_info) == 0) {
        printf("\n");
        printf("=== System Information ===\n");
        printf("System:    %s\n", sys_info.sysname);
        printf("Node:      %s\n", sys_info.nodename);
        printf("Release:   %s\n", sys_info.release);
        printf("Version:   %s\n", sys_info.version);
        printf("Machine:   %s\n", sys_info.machine);
        printf("==========================\n\n");
    }
}

int main(void)
{
    printf("\n");
    printf("╔════════════════════════════════════════════════╗\n");
    printf("║                                                ║\n");
    printf("║         DON'T PANIC                            ║\n");
    printf("║                                                ║\n");
    printf("║    The Hitchhiker's Guide to Embedded Linux   ║\n");
    printf("║                                                ║\n");
    printf("╚════════════════════════════════════════════════╝\n");
    printf("\n");
    
    printf("Hello from BeaglePlay!\n");
    printf("\n");
    
    printf("This program was cross-compiled for ARM64/AARCH64\n");
    printf("and is running on embedded Linux.\n");
    printf("\n");
    
    print_system_info();
    
    printf("🎉 Success! Your cross-compilation toolchain works!\n");
    printf("\n");
    printf("Remember: Always know where your towel is.\n");
    printf("          And your cross-compiler too.\n");
    printf("\n");
    
    return EXIT_SUCCESS;
}
