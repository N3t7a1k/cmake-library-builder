#include <netlink/netlink.h>
#include <netlink/socket.h>
#include <netlink/msg.h>
#include <netlink/attr.h>
#include <net/if.h>
#include <linux/rtnetlink.h>
#include <linux/if_arp.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <arpa/inet.h>

static char* format_mac(unsigned char* mac) {
    static char buf[32];
    snprintf(buf, sizeof(buf), "%02x:%02x:%02x:%02x:%02x:%02x", mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
    return buf;
}

static const char* get_hwtype_name(unsigned int type) {
    switch (type) {
        case ARPHRD_ETHER: return "Ethernet";
        case ARPHRD_LOOPBACK: return "Loopback";
        case ARPHRD_PPP: return "PPP";
        case ARPHRD_INFINIBAND: return "InfiniBand";
        case ARPHRD_NONE: return "None";
        default: return "Unknown";
    }
}

static const char* get_oper_state(unsigned int state) {
    switch (state) {
        case IF_OPER_UNKNOWN: return "Unknown";
        case IF_OPER_NOTPRESENT: return "Not Present";
        case IF_OPER_DOWN: return "Down";
        case IF_OPER_LOWERLAYERDOWN: return "Lower Layer Down";
        case IF_OPER_TESTING: return "Testing";
        case IF_OPER_DORMANT: return "Dormant";
        case IF_OPER_UP: return "Up";
        default: return "Unknown";
    }
}

static int callback(struct nl_msg *msg, void *arg) {
    struct nlmsghdr *nlh = nlmsg_hdr(msg);
    struct ifinfomsg *iface = NLMSG_DATA(nlh);
    struct nlattr *attrs[IFLA_MAX + 1];
    char flags_str[256] = {0};
    
    if (nlh->nlmsg_type != RTM_NEWLINK) {
        return NL_SKIP;
    }

    if (nlmsg_parse(nlh, sizeof(*iface), attrs, IFLA_MAX, NULL) < 0) {
        return NL_SKIP;
    }

    if (attrs[IFLA_IFNAME]) {
        printf("\n╭─ %s ", nla_get_string(attrs[IFLA_IFNAME]));
        printf("(Index: %d)\n", iface->ifi_index);

        if (attrs[IFLA_ADDRESS]) {
            printf("├ MAC: %s\n", format_mac(nla_data(attrs[IFLA_ADDRESS])));
        }

        printf("├ Type: %s\n", get_hwtype_name(iface->ifi_type));

        if (iface->ifi_flags) {
            if (iface->ifi_flags & IFF_UP) strcat(flags_str, "UP ");
            if (iface->ifi_flags & IFF_BROADCAST) strcat(flags_str, "BROADCAST ");
            if (iface->ifi_flags & IFF_DEBUG) strcat(flags_str, "DEBUG ");
            if (iface->ifi_flags & IFF_LOOPBACK) strcat(flags_str, "LOOPBACK ");
            if (iface->ifi_flags & IFF_POINTOPOINT) strcat(flags_str, "POINTOPOINT ");
            if (iface->ifi_flags & IFF_RUNNING) strcat(flags_str, "RUNNING ");
            if (iface->ifi_flags & IFF_NOARP) strcat(flags_str, "NOARP ");
            if (iface->ifi_flags & IFF_PROMISC) strcat(flags_str, "PROMISC ");
            if (iface->ifi_flags & IFF_MULTICAST) strcat(flags_str, "MULTICAST ");
            printf("├ Flags: %s\n", flags_str);
        }
        
        if (attrs[IFLA_MTU]) {
            printf("├ MTU: %d\n", nla_get_u32(attrs[IFLA_MTU]));
        }

        if (attrs[IFLA_OPERSTATE]) {
            printf("├ State: %s\n", get_oper_state(nla_get_u8(attrs[IFLA_OPERSTATE])));
        }

        if (attrs[IFLA_LINK_NETNSID]) {
            printf("├ Network Namespace ID: %d\n", nla_get_u32(attrs[IFLA_LINK_NETNSID]));
        }

        if (attrs[IFLA_TXQLEN]) {
            printf("├ TX Queue Length: %d\n", nla_get_u32(attrs[IFLA_TXQLEN]));
        }

        if (attrs[IFLA_PROMISCUITY]) {
            printf("├ Promiscuity Count: %d\n", nla_get_u32(attrs[IFLA_PROMISCUITY]));
        }

        if (attrs[IFLA_NUM_TX_QUEUES]) {
            printf("├ TX Queues: %d\n", nla_get_u32(attrs[IFLA_NUM_TX_QUEUES]));
        }

        if (attrs[IFLA_NUM_RX_QUEUES]) {
            printf("└ RX Queues: %d\n", nla_get_u32(attrs[IFLA_NUM_RX_QUEUES]));
        }

        printf("\n");
    }
    return NL_OK;
}

int main() {
    struct nl_sock *sock;
    int err;

    sock = nl_socket_alloc();
    if (!sock) {
        fprintf(stderr, "Failed to create socket\n");
        return 1;
    }

    if (nl_connect(sock, NETLINK_ROUTE) < 0) {
        fprintf(stderr, "Failed to connect netlink\n");
        nl_socket_free(sock);
        return 1;
    }

    struct nl_msg *msg = nlmsg_alloc();
    struct ifinfomsg ifi = {
        .ifi_family = AF_UNSPEC,
    };

    nlmsg_put(msg, NL_AUTO_PORT, NL_AUTO_SEQ, RTM_GETLINK, sizeof(ifi), NLM_F_REQUEST | NLM_F_DUMP);
    
    struct nlmsghdr *nlh = nlmsg_hdr(msg);
    memcpy(nlmsg_data(nlh), &ifi, sizeof(ifi));

    nl_socket_modify_cb(sock, NL_CB_VALID, NL_CB_CUSTOM, callback, NULL);
    
    err = nl_send_auto(sock, msg);
    if (err < 0) {
        fprintf(stderr, "Failed to send netlink message: %s\n", nl_geterror(err));
        nlmsg_free(msg);
        nl_socket_free(sock);
        return 1;
    }

    nl_recvmsgs_default(sock);
    nlmsg_free(msg);
    nl_socket_free(sock);
    return 0;
}
