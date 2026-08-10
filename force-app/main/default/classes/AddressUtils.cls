public class AddressUtils {

    public static String clean(String s) {
        if (s == null) { 
            return null; 
        }

        String cleaned = s
            .replace('\n', ' ')
            .replace('\r', ' ')
            .trim()
            .toUpperCase();

        return cleaned;
    }
}
