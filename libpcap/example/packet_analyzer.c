#include <pcap.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <signal.h>
#include <unistd.h>
#include <stdint.h>
#include <pthread.h>

#ifdef _WIN32
#include <winsock2.h>
#else
#include <arpa/inet.h>
#endif

typedef struct {
    unsigned long packets;
    unsigned long bytes;
    unsigned long tcp;
    unsigned long udp;
    unsigned long icmp;
    unsigned long other;
    time_t start_time;
} stats_t;

static stats_t stats = {0};
static pcap_t *handle = NULL;
static volatile int running = 1;

void signal_handler(int signo) {
    running = 0;
    if (handle) {
        pcap_breakloop(handle);
    }
}

void packet_handler(uint8_t *user, const struct pcap_pkthdr *header, const uint8_t *packet) {
    stats.packets++;
    stats.bytes += header->len;

    const uint8_t *ip_header = packet + 14;

    uint8_t protocol = ip_header[9];
    switch(protocol) {
        case 6:  
            stats.tcp++;
            break;
        case 17: 
            stats.udp++;
            break;
        case 1:  
            stats.icmp++;
            break;
        default:
            stats.other++;
    }
}

void print_stats() {
    time_t now = time(NULL);
    double elapsed = difftime(now, stats.start_time);
    
#ifdef _WIN32
    system("cls");
#else
    system("clear");
#endif
    
    printf("\nPacket Capture Statistics\n");
    printf("------------------------\n");
    printf("Running time: %.0f seconds\n", elapsed);
    printf("Total packets: %lu\n", stats.packets);
    printf("Total bytes: %lu\n", stats.bytes);
    printf("\nProtocol Distribution:\n");
    printf("TCP packets:  %lu (%.1f%%)\n", stats.tcp, 
           (stats.packets > 0) ? (stats.tcp * 100.0 / stats.packets) : 0);
    printf("UDP packets:  %lu (%.1f%%)\n", stats.udp,
           (stats.packets > 0) ? (stats.udp * 100.0 / stats.packets) : 0);
    printf("ICMP packets: %lu (%.1f%%)\n", stats.icmp,
           (stats.packets > 0) ? (stats.icmp * 100.0 / stats.packets) : 0);
    printf("Other:        %lu (%.1f%%)\n", stats.other,
           (stats.packets > 0) ? (stats.other * 100.0 / stats.packets) : 0);
    
    if (elapsed > 0) {
        printf("\nTraffic Rate:\n");
        printf("Packets/sec: %.1f\n", stats.packets / elapsed);
        printf("Bytes/sec:   %.1f\n", stats.bytes / elapsed);
    }
    
    printf("\nPress Ctrl+C to stop...\n");
}

void *print_thread_func(void *arg) {
    while (running) {
        print_stats();
        sleep(1);
    }
    return NULL;
}

int main(int argc, char *argv[]) {
    char errbuf[PCAP_ERRBUF_SIZE];

    if (argc != 2) {
        printf("Usage: %s <interface>\n", argv[0]);
        return 1;
    }

    signal(SIGINT, signal_handler);
    
    handle = pcap_open_live(argv[1], BUFSIZ, 1, 1000, errbuf);
    if (handle == NULL) {
        fprintf(stderr, "Couldn't open device %s: %s\n", argv[1], errbuf);
        return 2;
    }

    stats.start_time = time(NULL);

    printf("Starting capture on interface %s...\n", argv[1]);
    printf("Press Ctrl+C to stop.\n");

    pthread_t print_thread;
    if (pthread_create(&print_thread, NULL, print_thread_func, NULL) != 0) {
        fprintf(stderr, "Failed to create print thread.\n");
        pcap_close(handle);
        return 3;
    }

    while (running) {
        pcap_dispatch(handle, 1, packet_handler, NULL);
    }

    pthread_join(print_thread, NULL);

    print_stats();
    pcap_close(handle);
    printf("\nCapture complete.\n");
    
    return 0;
}
