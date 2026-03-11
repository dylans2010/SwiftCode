import Foundation
import CryptoKit

@available(iOS 13, *)
extension String {
    func md5() -> String {
        let data = Data(self.utf8)
        return Insecure.MD5.hash(data: data).map { String(format: "%02hhx", $0) }.joined()
    }
}
