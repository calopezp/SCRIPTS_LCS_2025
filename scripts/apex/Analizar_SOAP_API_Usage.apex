/**
 * Análisis de uso de SOAP API para autenticación
 * Identifica desarrollos, integraciones, usuarios y versiones
 */

// ============================================
// 1. BÚSQUEDA DE INTEGRACIONES EN EL CÓDIGO
// ============================================
System.debug(' → === ANÁLISIS DE CÓDIGO - BÚSQUEDA DE SOAP API ===');

// Buscar clases que contengan referencias a SOAP login
// Nota: Esto debe ejecutarse con herramientas de búsqueda de código
String[] soapKeywords = new String[]{
    'login()',
    'LoginResult',
    'SessionHeader',
    'Soap',
    'enterprise.soap',
    'partner.soap',
    'metadata.soap',
    'tooling.soap',
    'SforceService',
    'PartnerConnection',
    'EnterpriseConnection'
};

System.debug(' → Keywords a buscar en el código: ' + String.join(soapKeywords, ', '));

// ============================================
// 2. ANÁLISIS DE HISTORICO DE LOGIN - SOAP API
// ============================================
System.debug(' → \n=== ANÁLISIS DE LOGIN HISTORY - SOAP API ===');

try {
    // Últimos 30 días de logins vía SOAP API
    List<LoginHistory> soapLogins = [
        SELECT 
            Id,
            UserId,
            LoginTime,
            LoginType,
            SourceIp,
            LoginUrl,
            Application,
            Browser,
            Platform,
            Status,
            ApiType,
            ApiVersion,
            ClientVersion,
            AuthenticationServiceId
        FROM LoginHistory 
        WHERE LoginTime = LAST_N_DAYS:30
        ORDER BY LoginTime DESC
        LIMIT 10000
    ];
    
    // Filtrar solo logins SOAP en memoria (ApiType no es filtrable en WHERE)
    List<LoginHistory> filteredLogins = new List<LoginHistory>();
    for(LoginHistory login : soapLogins) {
        if(login.ApiType != null && login.ApiType.contains('SOAP')) {
            filteredLogins.add(login);
        }
    }
    soapLogins = filteredLogins;
    
    System.debug(' → Total SOAP API logins (últimos 30 días): ' + soapLogins.size());
    
    // Agrupar por usuario
    Map<Id, List<LoginHistory>> loginsByUser = new Map<Id, List<LoginHistory>>();
    Map<String, Integer> versionCount = new Map<String, Integer>();
    Map<String, Integer> applicationCount = new Map<String, Integer>();
    Set<Id> uniqueUsers = new Set<Id>();
    
    for(LoginHistory login : soapLogins) {
        // Por usuario
        uniqueUsers.add(login.UserId);
        if(!loginsByUser.containsKey(login.UserId)) {
            loginsByUser.put(login.UserId, new List<LoginHistory>());
        }
        loginsByUser.get(login.UserId).add(login);
        
        // Por versión API
        String version = login.ApiVersion != null ? String.valueOf(login.ApiVersion) : 'Unknown';
        versionCount.put(version, versionCount.containsKey(version) ? versionCount.get(version) + 1 : 1);
        
        // Por aplicación
        String app = login.Application != null ? login.Application : 'Unknown';
        applicationCount.put(app, applicationCount.containsKey(app) ? applicationCount.get(app) + 1 : 1);
    }
    
    System.debug(' → \n--- RESUMEN DE USUARIOS ---');
    System.debug(' → Total usuarios únicos con SOAP login: ' + uniqueUsers.size());
    
    // Obtener información de usuarios
    Map<Id, User> usersMap = new Map<Id, User>([
        SELECT Id, Name, Username, Email, Profile.Name, IsActive, UserType
        FROM User 
        WHERE Id IN :uniqueUsers
    ]);
    
    System.debug(' → \n--- TOP USUARIOS POR FRECUENCIA DE LOGIN SOAP ---');
    List<LoginCount> topUsers = new List<LoginCount>();
    for(Id userId : loginsByUser.keySet()) {
        User u = usersMap.get(userId);
        if(u != null) {
            LoginCount lc = new LoginCount();
            lc.userName = u.Name;
            lc.userEmail = u.Email;
            lc.profileName = u.Profile.Name;
            lc.isActive = u.IsActive;
            lc.loginCount = loginsByUser.get(userId).size();
            lc.lastLogin = loginsByUser.get(userId)[0].LoginTime;
            topUsers.add(lc);
        }
    }
    
    // Ordenar por cantidad de logins
    topUsers.sort();
    
    Integer displayCount = Math.min(20, topUsers.size());
    for(Integer i = 0; i < displayCount; i++) {
        LoginCount lc = topUsers[i];
        System.debug(String.format(
            '{0}. {1} ({2}) - Profile: {3} - Logins: {4} - Last: {5} - Active: {6}',
            new String[]{
                String.valueOf(i+1),
                lc.userName,
                lc.userEmail,
                lc.profileName,
                String.valueOf(lc.loginCount),
                lc.lastLogin.format('yyyy-MM-dd HH:mm:ss'),
                String.valueOf(lc.isActive)
            }
        ));
    }
    
    System.debug(' → \n--- VERSIONES DE API USADAS ---');
    List<String> sortedVersions = new List<String>(versionCount.keySet());
    sortedVersions.sort();
    for(String version : sortedVersions) {
        System.debug(String.format('API Version {0}: {1} logins', 
            new String[]{version, String.valueOf(versionCount.get(version))}));
    }
    
    System.debug(' → \n--- APLICACIONES USADAS ---');
    List<CountPair> appList = new List<CountPair>();
    for(String app : applicationCount.keySet()) {
        CountPair cp = new CountPair();
        cp.name = app;
        cp.count = applicationCount.get(app);
        appList.add(cp);
    }
    appList.sort();
    
    for(CountPair cp : appList) {
        System.debug(String.format('Application: {0} - {1} logins', 
            new String[]{cp.name, String.valueOf(cp.count)}));
    }
    
    // Mostrar ejemplos de logins recientes
    System.debug(' → \n--- ÚLTIMOS 10 LOGINS SOAP API ---');
    for(Integer i = 0; i < Math.min(10, soapLogins.size()); i++) {
        LoginHistory lh = soapLogins[i];
        User u = usersMap.get(lh.UserId);
        System.debug(String.format(
            '{0}. {1} - {2} - API v{3} - {4} - IP: {5}',
            new String[]{
                String.valueOf(i+1),
                lh.LoginTime.format('yyyy-MM-dd HH:mm:ss'),
                u != null ? u.Name : 'Unknown',
                String.valueOf(lh.ApiVersion),
                lh.Application != null ? lh.Application : 'N/A',
                lh.SourceIp
            }
        ));
    }
    
} catch(Exception e) {
    System.debug(' → Error consultando LoginHistory: ' + e.getMessage());
}

// ============================================
// 3. CONNECTED APPS CON SOAP HABILITADO
// ============================================
System.debug(' → \n=== CONNECTED APPS Y CONFIGURACIONES ===');

try {
    // Query de Connected Apps (requiere permisos especiales)
    List<ConnectedApplication> connectedApps = [
        SELECT Id, Name, CreatedDate, MobileStartUrl
        FROM ConnectedApplication
        LIMIT 100
    ];
    
    System.debug(' → Total Connected Apps: ' + connectedApps.size());
    for(ConnectedApplication app : connectedApps) {
        System.debug(' → - ' + app.Name + ' (Created: ' + app.CreatedDate.format() + ')');
    }
} catch(Exception e) {
    System.debug(' → No se pudo consultar Connected Apps: ' + e.getMessage());
    System.debug(' → Nota: Requiere permisos View Setup and Configuration');
}

// ============================================
// 4. INTEGRATION USERS
// ============================================
System.debug(' → \n=== USUARIOS DE INTEGRACIÓN ===');

try {
    List<User> integrationUsers = [
        SELECT Id, Name, Username, Email, Profile.Name, IsActive, 
               LastLoginDate, CreatedDate, UserType
        FROM User
        WHERE (Profile.Name LIKE '%Integration%' 
           OR Profile.Name LIKE '%API%'
           OR Username LIKE '%integration%'
           OR Username LIKE '%api%')
        AND IsActive = true
        ORDER BY LastLoginDate DESC NULLS LAST
    ];
    
    System.debug(' → Total usuarios de integración activos: ' + integrationUsers.size());
    for(User u : integrationUsers) {
        System.debug(String.format(
            '- {0} ({1}) - Profile: {2} - Last Login: {3}',
            new String[]{
                u.Name,
                u.Username,
                u.Profile.Name,
                u.LastLoginDate != null ? u.LastLoginDate.format('yyyy-MM-dd') : 'Never'
            }
        ));
    }
} catch(Exception e) {
    System.debug(' → Error consultando usuarios: ' + e.getMessage());
}

// ============================================
// 5. REMOTE SITE SETTINGS
// ============================================
System.debug(' → \n=== REMOTE SITE SETTINGS (ENDPOINTS EXTERNOS) ===');
System.debug(' → Nota: Remote Site Settings no son consultables vía SOQL.');
System.debug(' → Para revisar Remote Sites, ir a: Setup > Security > Remote Site Settings');
System.debug(' → O usar Metadata API / Tooling API para consultar este tipo de configuración.');

// ============================================
// 6. NAMED CREDENTIALS
// ============================================
System.debug(' → \n=== NAMED CREDENTIALS ===');

try {
    List<NamedCredential> credentials = [
        SELECT DeveloperName, MasterLabel, Endpoint
        FROM NamedCredential
        LIMIT 100
    ];
    
    System.debug(' → Total Named Credentials: ' + credentials.size());
    for(NamedCredential cred : credentials) {
        System.debug(' → - ' + cred.MasterLabel + ': ' + cred.Endpoint);
    }
} catch(Exception e) {
    System.debug(' → Error consultando Named Credentials: ' + e.getMessage());
}

// ============================================
// CLASES AUXILIARES
// ============================================
public class LoginCount implements Comparable {
    public String userName;
    public String userEmail;
    public String profileName;
    public Boolean isActive;
    public Integer loginCount;
    public DateTime lastLogin;
    
    public Integer compareTo(Object other) {
        LoginCount otherCount = (LoginCount)other;
        return otherCount.loginCount - this.loginCount; // Descendente
    }
}

public class CountPair implements Comparable {
    public String name;
    public Integer count;
    
    public Integer compareTo(Object other) {
        CountPair otherPair = (CountPair)other;
        return otherPair.count - this.count; // Descendente
    }
}

System.debug(' → \n=== ANÁLISIS COMPLETADO ===');
System.debug(' → \nRECOMENDACIONES:');
System.debug(' → 1. Revisar código fuente buscando las palabras clave mencionadas arriba');
System.debug(' → 2. Verificar Connected Apps en Setup > App Manager');
System.debug(' → 3. Revisar Integration Users y sus permisos');
System.debug(' → 4. Documentar todas las integraciones SOAP identificadas');
System.debug(' → 5. Considerar migración a REST API cuando sea posible');