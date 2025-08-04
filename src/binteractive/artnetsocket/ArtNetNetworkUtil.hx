package binteractive.artnetsocket;

/**
 * ArtNetNetworkUtil
 *
 * Utility for network interface discovery.
 * This class does not support config files or manual overrides.
 */
class ArtNetNetworkUtil {
    /**
     * Returns a list of local IPv4 addresses (private and public).
     * Useful for auto-detecting the local network interface.
     * @return Array of string IPs
     */
    public static function getLocalIPv4s():Array<String> {
        var addresses:Array<String> = [];
        #if sys
        var addr = sys.net.Host.localhost();
        if (~/^\d+\.\d+\.\d+\.\d+$/.match(addr)) addresses.push(addr);
        #end
        return addresses;
    }
}
