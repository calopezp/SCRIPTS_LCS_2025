/**
 * Análisis Detallado de Usuarios que Usan API
 * Muestra: Usuario | API Version | Aplicación/Integración | Fecha
 */

System.debug(' → ╔═══════════════════════════════════════════════════════════════╗');
System.debug(' → ║   ANÁLISIS DETALLADO DE USUARIOS Y USO DE API                 ║');
System.debug(' → ╚═══════════════════════════════════════════════════════════════╝\n');

try {
    // Consultar LoginHistory de los últimos 30 días
    List<LoginHistory> allLogins = [
        SELECT 
            Id,
            UserId,
            LoginTime,
            LoginType,
            SourceIp,
            Application,
            ApiType,
            ApiVersion,
            ClientVersion,
            Browser,
            Platform,
            Status
        FROM LoginHistory 
        WHERE LoginTime = LAST_N_DAYS:30
        ORDER BY LoginTime DESC
        LIMIT 10000
    ];
    
    // Filtrar logins con API después de la consulta
    List<LoginHistory> apiLogins = new List<LoginHistory>();
    for(LoginHistory login : allLogins) {
        if(login.ApiType != null) {
            apiLogins.add(login);
        }
    }
    allLogins = apiLogins;
    
    // Obtener información de usuarios
    Set<Id> userIds = new Set<Id>();
    for(LoginHistory login : allLogins) {
        userIds.add(login.UserId);
    }
    
    Map<Id, User> userMap = new Map<Id, User>([
        SELECT Id, Name, Username, Email, Profile.Name, IsActive
        FROM User
        WHERE Id IN :userIds
    ]);
    
    System.debug(' → Total de logins con API encontrados: ' + allLogins.size());
    System.debug(' → Periodo: Últimos 30 días\n');
    
    // Estructura para agrupar información
    Map<String, UserApiInfo> userApiMap = new Map<String, UserApiInfo>();
    
    // Procesar cada login
    for(LoginHistory login : allLogins) {
        String userKey = login.UserId;
        
        if(!userApiMap.containsKey(userKey)) {
            UserApiInfo info = new UserApiInfo();
            info.userId = login.UserId;
            /*info.userName = login.User.Name;
            info.userEmail = login.User.Username;
            info.profileName = login.User.Profile.Name;
            info.isActive = login.User.IsActive;*/
            info.logins = new List<LoginDetail>();
            userApiMap.put(userKey, info);
        }
        
        LoginDetail detail = new LoginDetail();
        detail.loginTime = login.LoginTime;
        detail.apiType = login.ApiType;
        detail.apiVersion = login.ApiVersion != null ? Decimal.valueOf(login.ApiVersion) : null;
        detail.application = login.Application;
        detail.sourceIp = login.SourceIp;
        detail.clientVersion = login.ClientVersion;
        detail.status = login.Status;
        
        userApiMap.get(userKey).logins.add(detail);
    }
    
    // Ordenar usuarios por cantidad de logins
    List<UserApiInfo> sortedUsers = userApiMap.values();
    sortedUsers.sort();
    
    System.debug(' → ═══════════════════════════════════════════════════════════════════');
    System.debug(' → RESUMEN POR USUARIO');
    System.debug(' → ═══════════════════════════════════════════════════════════════════\n');
    
    Integer userCounter = 0;
    for(UserApiInfo userInfo : sortedUsers) {
        userCounter++;
        
        System.debug(' → ┌─────────────────────────────────────────────────────────────────┐');
        System.debug(String.format('│ [{0}] USUARIO: {1}', new String[]{
            String.valueOf(userCounter),
            userInfo.userName
        }));
        System.debug(' → ├─────────────────────────────────────────────────────────────────┤');
        System.debug(' → │ Email/Username: ' + userInfo.userEmail);
        System.debug(' → │ Perfil: ' + userInfo.profileName);
        System.debug(' → │ Estado: ' + (userInfo.isActive ? 'ACTIVO' : 'INACTIVO'));
        System.debug(' → │ Total Logins API: ' + userInfo.logins.size());
        System.debug(' → ├─────────────────────────────────────────────────────────────────┤');
        
        // Agrupar por tipo de API
        Map<String, Integer> apiTypeCount = new Map<String, Integer>();
        Map<String, Integer> apiVersionCount = new Map<String, Integer>();
        Map<String, Integer> appCount = new Map<String, Integer>();
        
        for(LoginDetail detail : userInfo.logins) {
            // Contar por tipo API
            String apiType = detail.apiType != null ? detail.apiType : 'Unknown';
            apiTypeCount.put(apiType, apiTypeCount.containsKey(apiType) ? apiTypeCount.get(apiType) + 1 : 1);
            
            // Contar por versión
            String version = detail.apiVersion != null ? String.valueOf(detail.apiVersion) : 'Unknown';
            apiVersionCount.put(version, apiVersionCount.containsKey(version) ? apiVersionCount.get(version) + 1 : 1);
            
            // Contar por aplicación
            String app = detail.application != null ? detail.application : 'Unknown';
            appCount.put(app, appCount.containsKey(app) ? appCount.get(app) + 1 : 1);
        }
        
        // Mostrar tipos de API usados
        System.debug(' → │');
        System.debug(' → │ TIPOS DE API USADOS:');
        for(String apiType : apiTypeCount.keySet()) {
            System.debug(' → │   • ' + apiType + ': ' + apiTypeCount.get(apiType) + ' logins');
        }
        
        // Mostrar versiones API usadas
        System.debug(' → │');
        System.debug(' → │ VERSIONES DE API:');
        List<String> versions = new List<String>(apiVersionCount.keySet());
        versions.sort();
        for(String version : versions) {
            System.debug(' → │   • API v' + version + ': ' + apiVersionCount.get(version) + ' logins');
        }
        
        // Mostrar aplicaciones/integraciones
        System.debug(' → │');
        System.debug(' → │ APLICACIONES/INTEGRACIONES:');
        for(String app : appCount.keySet()) {
            System.debug(' → │   • ' + app + ': ' + appCount.get(app) + ' logins');
        }
        
        // Mostrar últimos 5 logins
        System.debug(' → │');
        System.debug(' → │ ÚLTIMOS 5 LOGINS:');
        Integer maxDisplay = Math.min(5, userInfo.logins.size());
        for(Integer i = 0; i < maxDisplay; i++) {
            LoginDetail detail = userInfo.logins[i];
            System.debug(' → │   ' + (i+1) + '. ' + detail.loginTime.format('yyyy-MM-dd HH:mm:ss'));
            System.debug(' → │      ├─ API: ' + detail.apiType + ' v' + detail.apiVersion);
            System.debug(' → │      ├─ App: ' + (detail.application != null ? detail.application : 'N/A'));
            System.debug(' → │      ├─ IP: ' + detail.sourceIp);
            System.debug(' → │      └─ Estado: ' + detail.status);
        }
        
        System.debug(' → └─────────────────────────────────────────────────────────────────┘\n');
        
        // Limitar a los primeros 20 usuarios para no exceder límites
        if(userCounter >= 20) {
            System.debug(' → ... Mostrando primeros 20 usuarios. Total: ' + sortedUsers.size() + ' usuarios.');
            break;
        }
    }
    
    // RESUMEN GENERAL
    System.debug(' → \n═══════════════════════════════════════════════════════════════════');
    System.debug(' → RESUMEN GENERAL');
    System.debug(' → ═══════════════════════════════════════════════════════════════════\n');
    
    // Consolidar totales
    Map<String, Integer> totalApiTypes = new Map<String, Integer>();
    Map<String, Integer> totalVersions = new Map<String, Integer>();
    Map<String, Integer> totalApps = new Map<String, Integer>();
    
    for(LoginHistory login : allLogins) {
        String apiType = login.ApiType != null ? login.ApiType : 'Unknown';
        totalApiTypes.put(apiType, totalApiTypes.containsKey(apiType) ? totalApiTypes.get(apiType) + 1 : 1);
        
        String version = login.ApiVersion != null ? String.valueOf(login.ApiVersion) : 'Unknown';
        totalVersions.put(version, totalVersions.containsKey(version) ? totalVersions.get(version) + 1 : 1);
        
        String app = login.Application != null ? login.Application : 'Unknown';
        totalApps.put(app, totalApps.containsKey(app) ? totalApps.get(app) + 1 : 1);
    }
    
    System.debug(' → 📊 TOTAL DE USUARIOS ÚNICOS: ' + userApiMap.size());
    System.debug(' → 📊 TOTAL DE LOGINS API: ' + allLogins.size());
    System.debug(' → 📊 PERIODO: Últimos 30 días\n');
    
    System.debug(' → --- TIPOS DE API (Total Organización) ---');
    for(String apiType : totalApiTypes.keySet()) {
        Integer count = totalApiTypes.get(apiType);
        Decimal percentage = (count * 100.0) / allLogins.size();
        System.debug(' → • ' + apiType + ': ' + count + ' logins (' + percentage.setScale(1) + '%)');
    }
    
    System.debug(' → \n--- VERSIONES DE API (Total Organización) ---');
    List<String> allVersions = new List<String>(totalVersions.keySet());
    allVersions.sort();
    for(String version : allVersions) {
        Integer count = totalVersions.get(version);
        Decimal percentage = (count * 100.0) / allLogins.size();
        System.debug(' → • API v' + version + ': ' + count + ' logins (' + percentage.setScale(1) + '%)');
    }
    
    System.debug(' → \n--- APLICACIONES/INTEGRACIONES (Total Organización) ---');
    List<AppCount> appCounts = new List<AppCount>();
    for(String app : totalApps.keySet()) {
        AppCount ac = new AppCount();
        ac.name = app;
        ac.count = totalApps.get(app);
        appCounts.add(ac);
    }
    appCounts.sort();
    
    for(AppCount ac : appCounts) {
        Decimal percentage = (ac.count * 100.0) / allLogins.size();
        System.debug(' → • ' + ac.name + ': ' + ac.count + ' logins (' + percentage.setScale(1) + '%)');
    }
    
    // Identificar logins SOAP específicamente
    Integer soapCount = 0;
    for(LoginHistory login : allLogins) {
        if(login.ApiType != null && login.ApiType.contains('SOAP')) {
            soapCount++;
        }
    }
    
    System.debug(' → \n⚠️  LOGINS VÍA SOAP API: ' + soapCount);
    if(soapCount > 0) {
        Decimal soapPercentage = (soapCount * 100.0) / allLogins.size();
        System.debug(' →     (' + soapPercentage.setScale(2) + '% del total)');
        System.debug(' →     🔴 RECOMENDACIÓN: Considerar migración a REST API');
    }
    
} catch(Exception e) {
    System.debug(' → ❌ ERROR: ' + e.getMessage());
    System.debug(' → Stack Trace: ' + e.getStackTraceString());
}

// ═══════════════════════════════════════════════════════════════════
// CLASES AUXILIARES
// ═══════════════════════════════════════════════════════════════════

public class UserApiInfo implements Comparable {
    public Id userId;
    public String userName;
    public String userEmail;
    public String profileName;
    public Boolean isActive;
    public List<LoginDetail> logins;
    
    public Integer compareTo(Object other) {
        UserApiInfo otherUser = (UserApiInfo)other;
        return otherUser.logins.size() - this.logins.size(); // Descendente por cantidad
    }
}

public class LoginDetail {
    public DateTime loginTime;
    public String apiType;
    public Decimal apiVersion;
    public String application;
    public String sourceIp;
    public String clientVersion;
    public String status;
}

public class AppCount implements Comparable {
    public String name;
    public Integer count;
    
    public Integer compareTo(Object other) {
        AppCount otherApp = (AppCount)other;
        return otherApp.count - this.count; // Descendente
    }
}

System.debug(' → \n═══════════════════════════════════════════════════════════════════');
System.debug(' → ✅ ANÁLISIS COMPLETADO');
System.debug(' → ═══════════════════════════════════════════════════════════════════\n');