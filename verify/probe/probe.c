// Emits struct offsets as assembler comments; compile with `make M=... probe.s`.
#include <linux/module.h>
#include <linux/skbuff.h>
#include <linux/netdevice.h>
#include <linux/usb.h>
#include <linux/usb/hcd.h>

#define OFF(s, m) asm volatile("\n.ascii \"@@ " #s "." #m " %0\"" :: "i"(offsetof(struct s, m)))
#define SZ(s) asm volatile("\n.ascii \"@@ sizeof." #s " %0\"" :: "i"(sizeof(struct s)))

void probe(void)
{
	SZ(device); SZ(usb_host_endpoint); SZ(urb); SZ(sk_buff); SZ(net_device); SZ(usb_device);
	SZ(usb_interface); SZ(napi_struct); SZ(work_struct); SZ(delayed_work); SZ(timer_list);
	SZ(spinlock); SZ(mutex); SZ(list_head); SZ(kobject); SZ(dev_pm_info); SZ(tasklet_struct);
	asm volatile("\n.ascii \"@@ sizeof.dma_addr_t %0\"" :: "i"(sizeof(dma_addr_t)));
	asm volatile("\n.ascii \"@@ sizeof.phys_addr_t %0\"" :: "i"(sizeof(phys_addr_t)));
	OFF(sk_buff, len); OFF(sk_buff, csum_start); OFF(sk_buff, priority); OFF(sk_buff, protocol);
	OFF(sk_buff, tail); OFF(sk_buff, end); OFF(sk_buff, head); OFF(sk_buff, data); OFF(sk_buff, users);
	OFF(net_device, flags); OFF(net_device, priv_flags); OFF(net_device, mtu); OFF(net_device, type);
	OFF(net_device, hard_header_len); OFF(net_device, addr_assign_type); OFF(net_device, addr_len);
	OFF(net_device, perm_addr); OFF(net_device, dev_addr); OFF(net_device, ethtool_ops);
	OFF(net_device, netdev_ops); OFF(net_device, features); OFF(net_device, state);
	OFF(net_device, operstate); OFF(net_device, priv_destructor); OFF(net_device, nd_net); OFF(net_device, ml_priv); OFF(net_device, ml_priv_type); OFF(net_device, tstats); OFF(net_device, link_watch_list); OFF(net_device, pcpu_refcnt); OFF(net_device, proto_down_reason); OFF(net_device, sysfs_groups); OFF(net_device, rtnl_link_ops); OFF(net_device, num_tc); SZ(netdev_queue);
	OFF(net_device, napi_list); OFF(net_device, dev); OFF(net_device, ieee80211_ptr);
	OFF(net_device, ip_ptr); OFF(net_device, rx_handler); OFF(net_device, _rx); OFF(net_device, _tx);
	OFF(net_device, qdisc); OFF(net_device, watchdog_timeo); OFF(net_device, gso_max_size);
	OFF(net_device, phydev); OFF(net_device, name_node); OFF(net_device, stats);
	OFF(usb_device, ep0); OFF(usb_device, dev); OFF(usb_device, descriptor); OFF(usb_device, state);
	OFF(usb_device, speed); OFF(usb_device, parent); OFF(usb_device, bus); OFF(usb_device, product);
	OFF(usb_device, actconfig); OFF(usb_device, ep_in);
	OFF(urb, dev); OFF(urb, ep); OFF(urb, pipe); OFF(urb, status); OFF(urb, transfer_flags);
	OFF(urb, transfer_buffer); OFF(urb, transfer_dma); OFF(urb, transfer_buffer_length);
	OFF(urb, actual_length); OFF(urb, setup_packet); OFF(urb, setup_dma); OFF(urb, context);
	OFF(urb, complete);
	OFF(usb_interface, dev); OFF(usb_interface, cur_altsetting); OFF(usb_interface, usb_dev);
	OFF(device, parent); OFF(device, driver_data); OFF(device, power); OFF(device, of_node);
	OFF(device, dma_mask); OFF(device, release);
	OFF(usb_bus, controller); OFF(usb_hcd, self);
}
MODULE_LICENSE("GPL");
