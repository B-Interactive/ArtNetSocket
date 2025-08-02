package binteractive.artnetsocket;

import sys.net.Host;
import haxe.Json;
import StringTools;

/**
 * Utility for network interface discovery and private subnet detection, prioritizing config file settings.
 */
class ArtNetNetworkUtil {

    /**
     * Loads ArtNetSocket config from a JSON file.
     * Returns a config object with defaults filled in for missing fields.
     */
    public static function loadConfig(path:String = "artnetsocket.config.json"):Dynamic {
        var defaults = {
            bind_interface: "auto",
            subnet_override: "",
            port: 6454
        };
        try {
            var content = sys.io.File.getContent(path);
            var cfg = Json.parse(content);
            // Fill in defaults for missing fields
            for (k in Reflect.fields(defaults)) {
                if (!Reflect.hasField(cfg, k)) Reflect.setField(cfg, k, Reflect.field(defaults, k));
            }
            return cfg;
        } catch (e:Dynamic) {
            return defaults;
        }
    }

    /**
     * Returns the best local interface IP to bind to.
     * If config specifies a valid IP, use it. Otherwise, auto-detect.
     */
    public static function getBindInterface(config:Dynamic):String {
        if (config != null && config.bind_interface != "auto" && config.bind_interface != "") {
            return config.bind_interface;
        }
        // Auto-detect local private IPs
        var localIPs = getLocalIPv4s();
        for (ip in localIPs) {
            if (StringTools.startsWith(ip, "192.168.") || StringTools.startsWith(ip, "10.") || (StringTools.startsWith(ip, "172.") && Std.parseInt(ip.split(".")[1]) >= 16 && Std.parseInt(ip.split(".")[1]) <= 31)) {
                return ip;
            }
        }
        return "0.0.0.0"; // fallback to all
    }

    /**
     * Returns the best subnet prefix for simulated broadcast.
     * If config specifies a valid subnet, use it. Otherwise, auto-detect.
     */
    public static function getPrivateSubnet(config:Dynamic):String {
        if (config != null && config.subnet_override != "" && ~/^\d+\.\d+\.\d+\.$/.match(config.subnet_override)) {
            return config.subnet_override;
        }
        var localIPs = getLocalIPv4s();
        for (ip in localIPs) {
            if (StringTools.startsWith(ip, "192.168.")) return ip.substr(0, ip.lastIndexOf(".") + 1);
            if (StringTools.startsWith(ip, "10.")) return ip.substr(0, ip.indexOf(".", 3) + 1);
            if (StringTools.startsWith(ip, "172.")) {
                var second = Std.parseInt(ip.split(".")[1]);
                if (second >= 16 && second <= 31) return ip.substr(0, ip.lastIndexOf(".") + 1);
            }
        }
        return "192.168.1."; // fallback
    }

    /**
     * Returns a list of local IPv4 addresses (private and public).
     */
    public static function getLocalIPv4s():Array<String> {
        var addresses:Array<String> = [];
        #if sys
        var addr = Host.localhost();
        if (~/^\d+\.\d+\.\d+\.\d+$/.match(addr)) addresses.push(addr);
        #end
        return addresses;
    }
}
