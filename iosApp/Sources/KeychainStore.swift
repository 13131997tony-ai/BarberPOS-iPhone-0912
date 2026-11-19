import Foundation
import Security

/** Prepared secure-storage adapter. The starter currently uses memory-only sessions. */
struct KeychainStore {
    let service = "vn.barberpos.ios.session"
    func read(account: String) -> Data? {
        let query:[String:Any]=[kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service,
            kSecAttrAccount as String:account,kSecReturnData as String:true,kSecMatchLimit as String:kSecMatchLimitOne]
        var result:CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary,&result)==errSecSuccess else{return nil}
        return result as? Data
    }
    func save(account:String,data:Data) throws {
        clear(account:account)
        let item:[String:Any]=[kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service,
            kSecAttrAccount as String:account,kSecValueData as String:data,
            kSecAttrAccessible as String:kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        let status=SecItemAdd(item as CFDictionary,nil)
        guard status==errSecSuccess else{throw NSError(domain:NSOSStatusErrorDomain,code:Int(status))}
    }
    func clear(account:String) {
        SecItemDelete([kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service,
            kSecAttrAccount as String:account] as CFDictionary)
    }
}
