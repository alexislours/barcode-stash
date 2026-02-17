#if DEBUG
    import Foundation
    import SwiftData

    enum MockDataSeeder {
        // MARK: - Locale-configurable content

        struct LocaleContent {
            let description: String?
            let tags: [String]
            let latitude: Double?
            let longitude: Double?
            let address: String?

            init(
                description: String?,
                tags: [String],
                latitude: Double? = nil,
                longitude: Double? = nil,
                address: String? = nil
            ) {
                self.description = description
                self.tags = tags
                self.latitude = latitude
                self.longitude = longitude
                self.address = address
            }
        }

        /// Per-barcode locale overrides keyed by language prefix (e.g. "en", "fr", "zh-Hans").
        /// Falls back to "en" when the current language has no entry.
        /// Add new languages by inserting entries into each barcode's locale map.
        private static let entries: [(skeleton: BarcodeSkeleton, locales: [String: LocaleContent])] = [
            // Today - varied types with locations
            (
                BarcodeSkeleton(
                    rawValue: "https://en.wikipedia.org/wiki/Barcode",
                    type: .qr,
                    hoursAgo: 1,
                    isFavorite: true
                ),
                [
                    "en": LocaleContent(description: "Wikipedia article on barcodes", tags: ["reference", "web"], latitude: 40.7484, longitude: -73.9857, address: "Midtown Manhattan, New York"),
                    "es": LocaleContent(description: "Artículo de Wikipedia sobre códigos de barras", tags: ["referencia", "web"], latitude: 40.4168, longitude: -3.7038, address: "Puerta del Sol, Madrid"),
                    "fr": LocaleContent(description: "Article Wikipédia sur les codes-barres", tags: ["référence", "web"], latitude: 48.8584, longitude: 2.2945, address: "Tour Eiffel, Paris"),
                    "pt": LocaleContent(description: "Artigo da Wikipédia sobre códigos de barras", tags: ["referência", "web"], latitude: -22.9068, longitude: -43.1729, address: "Centro, Rio de Janeiro"),
                    "de": LocaleContent(description: "Wikipedia-Artikel über Barcodes", tags: ["Referenz", "Web"], latitude: 52.5163, longitude: 13.3777, address: "Brandenburger Tor, Berlin"),
                    "it": LocaleContent(description: "Articolo Wikipedia sui codici a barre", tags: ["riferimento", "web"], latitude: 41.8902, longitude: 12.4922, address: "Colosseo, Roma"),
                    "ja": LocaleContent(description: "バーコードのWikipedia記事", tags: ["参考", "ウェブ"], latitude: 35.6595, longitude: 139.7004, address: "渋谷スクランブル交差点, 東京"),
                    "ko": LocaleContent(description: "바코드 위키백과 문서", tags: ["참고", "웹"], latitude: 37.5760, longitude: 126.9769, address: "광화문광장, 서울"),
                    "zh-Hans": LocaleContent(description: "维基百科条形码词条", tags: ["参考", "网站"], latitude: 39.9087, longitude: 116.3975, address: "天安门广场, 北京"),
                    "zh-Hant": LocaleContent(description: "維基百科條碼詞條", tags: ["參考", "網站"], latitude: 25.0340, longitude: 121.5645, address: "台北101, 台北"),
                ]
            ),
            (
                BarcodeSkeleton(
                    rawValue: "0049000006346",
                    type: .ean13,
                    hoursAgo: 2
                ),
                [
                    "en": LocaleContent(description: "Coca-Cola 12oz can", tags: ["grocery"], latitude: 40.7580, longitude: -73.9855, address: "Times Square, New York"),
                    "es": LocaleContent(description: "Lata de Mahou Cinco Estrellas 33cl", tags: ["supermercado"], latitude: 40.4200, longitude: -3.7025, address: "Gran Vía, Madrid"),
                    "fr": LocaleContent(description: "Canette Orangina 33cl", tags: ["courses"], latitude: 48.8698, longitude: 2.3076, address: "Champs-Élysées, Paris"),
                    "pt": LocaleContent(description: "Lata de Guaraná Antarctica 350ml", tags: ["mercado"], latitude: -23.5505, longitude: -46.6333, address: "Av. Paulista, São Paulo"),
                    "de": LocaleContent(description: "Fritz-Kola 0,33l Flasche", tags: ["Einkauf"], latitude: 48.1374, longitude: 11.5755, address: "Marienplatz, München"),
                    "it": LocaleContent(description: "Lattina di San Pellegrino Aranciata 33cl", tags: ["spesa"], latitude: 45.4642, longitude: 9.1900, address: "Piazza del Duomo, Milano"),
                    "ja": LocaleContent(description: "サントリー伊右衛門 緑茶 500ml", tags: ["食料品"], latitude: 35.6938, longitude: 139.7034, address: "新宿駅南口, 東京"),
                    "ko": LocaleContent(description: "빙그레 바나나맛 우유 240ml", tags: ["식료품"], latitude: 37.5636, longitude: 126.9830, address: "명동거리, 서울"),
                    "zh-Hans": LocaleContent(description: "农夫山泉矿泉水 550ml", tags: ["食品"], latitude: 31.2304, longitude: 121.4737, address: "南京路步行街, 上海"),
                    "zh-Hant": LocaleContent(description: "黑松沙士 330ml", tags: ["食品"], latitude: 25.0422, longitude: 121.5079, address: "西門町, 台北"),
                ]
            ),
            (
                BarcodeSkeleton(
                    rawValue: "0071660309046",
                    type: .ean13,
                    hoursAgo: 3,
                    isFavorite: true
                ),
                [
                    "en": LocaleContent(description: "Sharpie marker set", tags: ["stationery", "art"], latitude: 40.7527, longitude: -73.9772, address: "Grand Central, New York"),
                    "es": LocaleContent(description: "Set de rotuladores Alpino", tags: ["papelería", "arte"], latitude: 40.4138, longitude: -3.6986, address: "Barrio de las Letras, Madrid"),
                    "fr": LocaleContent(description: "Lot de stylos BIC Cristal", tags: ["papeterie", "bureau"], latitude: 48.8566, longitude: 2.3522, address: "Le Marais, Paris"),
                    "pt": LocaleContent(description: "Kit de canetas Faber-Castell", tags: ["papelaria", "arte"], latitude: -23.5614, longitude: -46.6558, address: "Liberdade, São Paulo"),
                    "de": LocaleContent(description: "Stabilo Textmarker-Set", tags: ["Büro", "Kunst"], latitude: 52.5200, longitude: 13.4050, address: "Alexanderplatz, Berlin"),
                    "it": LocaleContent(description: "Set di pennarelli Giotto", tags: ["cartoleria", "arte"], latitude: 43.7687, longitude: 11.2569, address: "Ponte Vecchio, Firenze"),
                    "ja": LocaleContent(description: "パイロット フリクションペンセット", tags: ["文房具", "アート"], latitude: 35.6717, longitude: 139.7649, address: "銀座四丁目交差点, 東京"),
                    "ko": LocaleContent(description: "모나미 153 볼펜 세트", tags: ["문구", "아트"], latitude: 37.5172, longitude: 127.0473, address: "강남역, 서울"),
                    "zh-Hans": LocaleContent(description: "晨光中性笔套装", tags: ["文具", "艺术"], latitude: 39.9139, longitude: 116.4103, address: "王府井大街, 北京"),
                    "zh-Hant": LocaleContent(description: "百樂摩磨擦鋼珠筆組", tags: ["文具", "藝術"], latitude: 25.0362, longitude: 121.5672, address: "信義誠品, 台北"),
                ]
            ),
            (
                BarcodeSkeleton(
                    rawValue: "WIFI:T:WPA;S:CafeWifi;P:welcome2024;;",
                    type: .qr,
                    hoursAgo: 5
                ),
                [
                    "en": LocaleContent(description: "Coffee shop WiFi", tags: ["wifi"], latitude: 40.7295, longitude: -73.9965, address: "Greenwich Village, New York"),
                    "es": LocaleContent(description: "WiFi de la cafetería", tags: ["wifi"], latitude: 41.3851, longitude: 2.1834, address: "El Born, Barcelona"),
                    "fr": LocaleContent(description: "WiFi du café", tags: ["wifi"], latitude: 48.8539, longitude: 2.3338, address: "Saint-Germain-des-Prés, Paris"),
                    "pt": LocaleContent(description: "WiFi da padaria", tags: ["wifi"], latitude: -22.9519, longitude: -43.2105, address: "Leblon, Rio de Janeiro"),
                    "de": LocaleContent(description: "WLAN im Café", tags: ["WLAN"], latitude: 53.5631, longitude: 9.9632, address: "Schanzenviertel, Hamburg"),
                    "it": LocaleContent(description: "WiFi del bar", tags: ["wifi"], latitude: 41.8796, longitude: 12.4701, address: "Trastevere, Roma"),
                    "ja": LocaleContent(description: "カフェのWiFi", tags: ["wifi"], latitude: 35.6613, longitude: 139.6680, address: "下北沢, 東京"),
                    "ko": LocaleContent(description: "카페 WiFi", tags: ["wifi"], latitude: 37.5563, longitude: 126.9236, address: "홍대입구, 서울"),
                    "zh-Hans": LocaleContent(description: "咖啡店WiFi", tags: ["wifi"], latitude: 31.2390, longitude: 121.4765, address: "田子坊, 上海"),
                    "zh-Hant": LocaleContent(description: "咖啡廳WiFi", tags: ["wifi"], latitude: 25.0308, longitude: 121.5295, address: "永康街, 台北"),
                ]
            ),

            (
                BarcodeSkeleton(
                    rawValue: "4006381333931",
                    type: .ean13,
                    hoursAgo: 6
                ),
                [
                    "en": LocaleContent(description: "Staedtler Noris pencil set", tags: ["stationery", "art"], latitude: 40.7484, longitude: -73.9857, address: "Midtown Manhattan, New York"),
                    "es": LocaleContent(description: "Set de lápices Staedtler Noris", tags: ["papelería", "arte"], latitude: 41.3809, longitude: 2.1734, address: "Las Ramblas, Barcelona"),
                    "fr": LocaleContent(description: "Lot de crayons Staedtler Noris", tags: ["papeterie", "art"], latitude: 48.8566, longitude: 2.3522, address: "Le Marais, Paris"),
                    "pt": LocaleContent(description: "Conjunto de lápis Faber-Castell", tags: ["papelaria", "arte"], latitude: -23.5475, longitude: -46.6361, address: "Sé, São Paulo"),
                    "de": LocaleContent(description: "Staedtler Noris Bleistiftset", tags: ["Büro", "Kunst"], latitude: 49.4521, longitude: 11.0767, address: "Altstadt, Nürnberg"),
                    "it": LocaleContent(description: "Set di matite Staedtler Noris", tags: ["cartoleria", "arte"], latitude: 45.4341, longitude: 12.3388, address: "Piazza San Marco, Venezia"),
                    "ja": LocaleContent(description: "トンボ鉛筆 MONO セット", tags: ["文房具", "アート"], latitude: 34.9949, longitude: 135.7850, address: "清水寺, 京都"),
                    "ko": LocaleContent(description: "알파 샤프펜슬 세트", tags: ["문구", "아트"], latitude: 37.5724, longitude: 126.9857, address: "인사동길, 서울"),
                    "zh-Hans": LocaleContent(description: "得力铅笔套装", tags: ["文具", "艺术"], latitude: 30.2590, longitude: 120.2196, address: "西湖景区, 杭州"),
                    "zh-Hant": LocaleContent(description: "利百代鉛筆組", tags: ["文具", "藝術"], latitude: 25.0444, longitude: 121.5597, address: "松山文創園區, 台北"),
                ]
            ),

            // Yesterday
            (
                BarcodeSkeleton(
                    rawValue: "SHIP-2024-98765",
                    type: .code128,
                    hoursAgo: 25
                ),
                [
                    "en": LocaleContent(description: "Amazon delivery label", tags: ["shipping"], latitude: 34.0522, longitude: -118.2437, address: "Downtown Los Angeles, CA"),
                    "es": LocaleContent(description: "Etiqueta de envío SEUR", tags: ["envío"], latitude: 37.3886, longitude: -6.0000, address: "Triana, Sevilla"),
                    "fr": LocaleContent(description: "Étiquette Colissimo", tags: ["livraison"], latitude: 45.7640, longitude: 4.8357, address: "Presqu'île, Lyon"),
                    "pt": LocaleContent(description: "Etiqueta de entrega Mercado Livre", tags: ["entrega"], latitude: -22.9035, longitude: -43.2096, address: "Copacabana, Rio de Janeiro"),
                    "de": LocaleContent(description: "DHL-Paketaufkleber", tags: ["Versand"], latitude: 50.1109, longitude: 8.6821, address: "Innenstadt, Frankfurt am Main"),
                    "it": LocaleContent(description: "Etichetta spedizione Amazon", tags: ["spedizione"], latitude: 43.7696, longitude: 11.2558, address: "Via Tornabuoni, Firenze"),
                    "ja": LocaleContent(description: "ヤマト運輸 配送ラベル", tags: ["配送"], latitude: 34.6627, longitude: 135.5014, address: "なんば, 大阪"),
                    "ko": LocaleContent(description: "CJ대한통운 배송 라벨", tags: ["배송"], latitude: 35.1580, longitude: 129.1604, address: "해운대해수욕장, 부산"),
                    "zh-Hans": LocaleContent(description: "顺丰快递面单", tags: ["快递"], latitude: 22.5431, longitude: 114.0579, address: "华强北, 深圳"),
                    "zh-Hant": LocaleContent(description: "蝦皮購物出貨標籤", tags: ["物流"], latitude: 25.0478, longitude: 121.5170, address: "台北車站, 台北"),
                ]
            ),
            (
                BarcodeSkeleton(
                    rawValue: "04210000526",
                    type: .upce,
                    hoursAgo: 26
                ),
                [
                    "en": LocaleContent(description: "Wrigley's gum", tags: ["grocery", "snack"], latitude: 41.8781, longitude: -87.6298, address: "The Loop, Chicago, IL"),
                    "es": LocaleContent(description: "Chicle Orbit menta", tags: ["supermercado", "snack"], latitude: 39.8886, longitude: 4.2658, address: "Puerto de Mahón, Menorca"),
                    "fr": LocaleContent(description: "Chewing-gum Hollywood", tags: ["courses", "snack"], latitude: 43.2965, longitude: 5.3698, address: "Vieux-Port, Marseille"),
                    "pt": LocaleContent(description: "Chiclete Trident", tags: ["mercado", "lanche"], latitude: -12.9714, longitude: -38.5124, address: "Pelourinho, Salvador"),
                    "de": LocaleContent(description: "Haribo Goldbären", tags: ["Einkauf", "Snack"], latitude: 50.9375, longitude: 6.9603, address: "Altstadt, Köln"),
                    "it": LocaleContent(description: "Gomma da masticare Vigorsol", tags: ["spesa", "snack"], latitude: 40.3516, longitude: 18.1718, address: "Piazza del Duomo, Lecce"),
                    "ja": LocaleContent(description: "明治チョコレート", tags: ["食料品", "おやつ"], latitude: 34.6687, longitude: 135.5013, address: "道頓堀, 大阪"),
                    "ko": LocaleContent(description: "롯데 자일리톨 껌", tags: ["식료품", "간식"], latitude: 35.0986, longitude: 129.0322, address: "남포동, 부산"),
                    "zh-Hans": LocaleContent(description: "旺旺仙贝大礼包", tags: ["食品", "零食"], latitude: 30.5728, longitude: 104.0668, address: "春熙路, 成都"),
                    "zh-Hant": LocaleContent(description: "義美小泡芙", tags: ["食品", "零食"], latitude: 25.0882, longitude: 121.5244, address: "士林夜市, 台北"),
                ]
            ),
            (
                BarcodeSkeleton(
                    rawValue: "96385074",
                    type: .ean8,
                    hoursAgo: 28
                ),
                [
                    "en": LocaleContent(description: "Duracell battery pack", tags: []),
                    "es": LocaleContent(description: "Pack de pilas Duracell", tags: []),
                    "fr": LocaleContent(description: "Pack de piles Duracell", tags: []),
                    "pt": LocaleContent(description: "Pacote de pilhas Rayovac", tags: []),
                    "de": LocaleContent(description: "Varta Batteriepack", tags: []),
                    "it": LocaleContent(description: "Pacco di pile Duracell", tags: []),
                    "ja": LocaleContent(description: "パナソニック エボルタ電池パック", tags: []),
                    "ko": LocaleContent(description: "LG 건전지 팩", tags: []),
                    "zh-Hans": LocaleContent(description: "南孚电池套装", tags: []),
                    "zh-Hant": LocaleContent(description: "勁量電池組", tags: []),
                ]
            ),
            (
                BarcodeSkeleton(
                    rawValue: "BEGIN:VCARD\nVERSION:3.0\nFN:Sarah Johnson\nTEL:+14155551234\nEMAIL:sarah@example.com\nEND:VCARD",
                    type: .qr,
                    hoursAgo: 30,
                    isFavorite: true
                ),
                [
                    "en": LocaleContent(description: "Sarah's business card", tags: ["contact"], latitude: 37.7749, longitude: -122.4194, address: "Union Square, San Francisco, CA"),
                    "es": LocaleContent(description: "Tarjeta de visita de María", tags: ["contacto"], latitude: 40.4400, longitude: -3.6900, address: "Paseo de la Castellana, Madrid"),
                    "fr": LocaleContent(description: "Carte de visite de Sarah", tags: ["contact"], latitude: 51.5074, longitude: -0.1278, address: "Westminster, Londres"),
                    "pt": LocaleContent(description: "Cartão de visita da Fernanda", tags: ["contato"], latitude: -15.7942, longitude: -47.8825, address: "Esplanada dos Ministérios, Brasília"),
                    "de": LocaleContent(description: "Visitenkarte von Thomas", tags: ["Kontakt"], latitude: 48.7758, longitude: 9.1829, address: "Königstraße, Stuttgart"),
                    "it": LocaleContent(description: "Biglietto da visita di Marco", tags: ["contatto"], latitude: 41.8992, longitude: 12.4731, address: "Piazza Navona, Roma"),
                    "ja": LocaleContent(description: "田中さんの名刺", tags: ["連絡先"], latitude: 35.4558, longitude: 139.6328, address: "みなとみらい, 横浜"),
                    "ko": LocaleContent(description: "김민수 님의 명함", tags: ["연락처"], latitude: 37.5219, longitude: 126.9245, address: "여의도공원, 서울"),
                    "zh-Hans": LocaleContent(description: "王明的名片", tags: ["联系人"], latitude: 30.2741, longitude: 120.1551, address: "西溪湿地, 杭州"),
                    "zh-Hant": LocaleContent(description: "林小姐的名片", tags: ["聯絡人"], latitude: 25.0350, longitude: 121.5219, address: "中正紀念堂, 台北"),
                ]
            ),

            // 3 days ago
            (
                BarcodeSkeleton(
                    rawValue: "INV 4521 A",
                    type: .code93,
                    hoursAgo: 74
                ),
                [
                    "en": LocaleContent(description: "Warehouse inventory label", tags: ["work"]),
                    "es": LocaleContent(description: "Etiqueta de inventario del almacén", tags: ["trabajo"]),
                    "fr": LocaleContent(description: "Étiquette inventaire entrepôt", tags: ["travail"]),
                    "pt": LocaleContent(description: "Etiqueta de inventário do depósito", tags: ["trabalho"]),
                    "de": LocaleContent(description: "Lager-Inventuretikett", tags: ["Arbeit"]),
                    "it": LocaleContent(description: "Etichetta inventario magazzino", tags: ["lavoro"]),
                    "ja": LocaleContent(description: "倉庫の在庫ラベル", tags: ["仕事"]),
                    "ko": LocaleContent(description: "창고 재고 라벨", tags: ["업무"]),
                    "zh-Hans": LocaleContent(description: "仓库库存标签", tags: ["工作"]),
                    "zh-Hant": LocaleContent(description: "倉庫庫存標籤", tags: ["工作"]),
                ]
            ),
            (
                BarcodeSkeleton(
                    rawValue: "PDF417-BOARDING-PASS-SFO-JFK-2024",
                    type: .pdf417,
                    hoursAgo: 72,
                    isFavorite: true
                ),
                [
                    "en": LocaleContent(description: "Boarding pass SFO → JFK", tags: ["travel"], latitude: 37.6213, longitude: -122.3790, address: "SFO Airport, San Francisco, CA"),
                    "es": LocaleContent(description: "Tarjeta de embarque MAD → BCN", tags: ["viaje"], latitude: 40.4719, longitude: -3.5626, address: "Aeropuerto de Barajas, Madrid"),
                    "fr": LocaleContent(description: "Carte d'embarquement CDG → NCE", tags: ["voyage"], latitude: 49.0097, longitude: 2.5479, address: "Aéroport CDG, Roissy-en-France"),
                    "pt": LocaleContent(description: "Cartão de embarque GRU → GIG", tags: ["viagem"], latitude: -23.4356, longitude: -46.4731, address: "Aeroporto de Guarulhos, São Paulo"),
                    "de": LocaleContent(description: "Bordkarte MUC → HAM", tags: ["Reise"], latitude: 48.3537, longitude: 11.7750, address: "Flughafen München"),
                    "it": LocaleContent(description: "Carta d'imbarco FCO → MXP", tags: ["viaggio"], latitude: 41.8003, longitude: 12.2389, address: "Aeroporto di Fiumicino, Roma"),
                    "ja": LocaleContent(description: "搭乗券 NRT → KIX", tags: ["旅行"], latitude: 35.7720, longitude: 140.3929, address: "成田国際空港, 千葉"),
                    "ko": LocaleContent(description: "탑승권 ICN → CJU", tags: ["여행"], latitude: 37.4602, longitude: 126.4407, address: "인천국제공항"),
                    "zh-Hans": LocaleContent(description: "登机牌 PEK → SHA", tags: ["旅行"], latitude: 40.0799, longitude: 116.6031, address: "首都国际机场, 北京"),
                    "zh-Hant": LocaleContent(description: "登機證 TPE → NRT", tags: ["旅行"], latitude: 25.0777, longitude: 121.2329, address: "桃園國際機場"),
                ]
            ),
            (
                BarcodeSkeleton(
                    rawValue: "00850007942011",
                    type: .itf14,
                    hoursAgo: 73
                ),
                [
                    "en": LocaleContent(description: "UPS shipping carton", tags: []),
                    "es": LocaleContent(description: "Caja de envío Correos", tags: []),
                    "fr": LocaleContent(description: "Carton d'expédition La Poste", tags: []),
                    "pt": LocaleContent(description: "Caixa de envio Correios", tags: []),
                    "de": LocaleContent(description: "Hermes-Versandkarton", tags: []),
                    "it": LocaleContent(description: "Scatola spedizione Poste Italiane", tags: []),
                    "ja": LocaleContent(description: "佐川急便 配送箱", tags: []),
                    "ko": LocaleContent(description: "한진택배 배송 박스", tags: []),
                    "zh-Hans": LocaleContent(description: "中通快递包裹箱", tags: []),
                    "zh-Hant": LocaleContent(description: "黑貓宅急便包裹箱", tags: []),
                ]
            ),

            // Last week
            (
                BarcodeSkeleton(
                    rawValue: "https://developer.apple.com",
                    type: .aztec,
                    hoursAgo: 169,
                    isFavorite: true
                ),
                [
                    "en": LocaleContent(description: "WWDC conference badge", tags: ["tech", "conference"], latitude: 37.3308, longitude: -122.0074, address: "Apple Park, Cupertino, CA"),
                    "es": LocaleContent(description: "Acreditación conferencia WWDC", tags: ["tech", "conferencia"], latitude: 39.4539, longitude: -0.3476, address: "Ciudad de las Artes, Valencia"),
                    "fr": LocaleContent(description: "Badge conférence WWDC", tags: ["tech", "conférence"], latitude: 51.5155, longitude: -0.0922, address: "Tower Bridge, Londres"),
                    "pt": LocaleContent(description: "Crachá da conferência WWDC", tags: ["tech", "conferência"], latitude: -30.0346, longitude: -51.2177, address: "Centro Histórico, Porto Alegre"),
                    "de": LocaleContent(description: "WWDC Konferenz-Badge", tags: ["Tech", "Konferenz"], latitude: 51.2277, longitude: 6.7735, address: "Altstadt, Düsseldorf"),
                    "it": LocaleContent(description: "Badge conferenza WWDC", tags: ["tech", "conferenza"], latitude: 40.8358, longitude: 14.2488, address: "Piazza del Plebiscito, Napoli"),
                    "ja": LocaleContent(description: "WWDCカンファレンスバッジ", tags: ["テック", "カンファレンス"], latitude: 35.6984, longitude: 139.7731, address: "秋葉原, 東京"),
                    "ko": LocaleContent(description: "WWDC 컨퍼런스 배지", tags: ["기술", "컨퍼런스"], latitude: 37.3945, longitude: 127.1112, address: "판교테크노밸리, 성남"),
                    "zh-Hans": LocaleContent(description: "WWDC开发者大会徽章", tags: ["科技", "大会"], latitude: 39.9847, longitude: 116.3046, address: "中关村, 北京"),
                    "zh-Hant": LocaleContent(description: "WWDC開發者大會識別證", tags: ["科技", "大會"], latitude: 25.0560, longitude: 121.6177, address: "南港展覽館, 台北"),
                ]
            ),
            (
                BarcodeSkeleton(
                    rawValue: "01034531200000111719112510ABCD1234",
                    type: .dataMatrix,
                    hoursAgo: 173
                ),
                [
                    "en": LocaleContent(description: "Prescription medication", tags: ["health"], latitude: 29.7604, longitude: -95.3698, address: "Texas Medical Center, Houston, TX"),
                    "es": LocaleContent(description: "Medicamento con receta", tags: ["salud"], latitude: 40.4812, longitude: -3.6868, address: "Hospital La Paz, Madrid"),
                    "fr": LocaleContent(description: "Médicament sur ordonnance", tags: ["santé"], latitude: 44.8378, longitude: -0.5792, address: "Centre-ville, Bordeaux"),
                    "pt": LocaleContent(description: "Medicamento com receita", tags: ["saúde"], latitude: -19.9167, longitude: -43.9345, address: "Savassi, Belo Horizonte"),
                    "de": LocaleContent(description: "Rezeptpflichtiges Medikament", tags: ["Gesundheit"], latitude: 48.1351, longitude: 11.5820, address: "Schwabing, München"),
                    "it": LocaleContent(description: "Farmaco con ricetta", tags: ["salute"], latitude: 41.9311, longitude: 12.4356, address: "Policlinico Gemelli, Roma"),
                    "ja": LocaleContent(description: "処方薬", tags: ["健康"], latitude: 35.6940, longitude: 139.7038, address: "新宿区, 東京"),
                    "ko": LocaleContent(description: "처방 의약품", tags: ["건강"], latitude: 37.5790, longitude: 126.9990, address: "서울대학교병원, 서울"),
                    "zh-Hans": LocaleContent(description: "处方药品", tags: ["健康"], latitude: 31.2072, longitude: 121.4311, address: "瑞金医院, 上海"),
                    "zh-Hant": LocaleContent(description: "處方藥品", tags: ["健康"], latitude: 25.0400, longitude: 121.5226, address: "台大醫院, 台北"),
                ]
            ),
            (
                BarcodeSkeleton(
                    rawValue: "ABC-12345",
                    type: .code39,
                    hoursAgo: 168
                ),
                [
                    "en": LocaleContent(description: "Smithsonian museum ticket", tags: ["travel", "culture"], latitude: 38.8881, longitude: -77.0199, address: "National Mall, Washington, DC"),
                    "es": LocaleContent(description: "Entrada al Museo del Prado", tags: ["viaje", "cultura"], latitude: 40.4138, longitude: -3.6921, address: "Museo del Prado, Madrid"),
                    "fr": LocaleContent(description: "Billet musée du Louvre", tags: ["voyage", "culture"], latitude: 48.8606, longitude: 2.3376, address: "Musée du Louvre, Paris"),
                    "pt": LocaleContent(description: "Ingresso do MASP", tags: ["viagem", "cultura"], latitude: -23.5614, longitude: -46.6558, address: "MASP, Av. Paulista, São Paulo"),
                    "de": LocaleContent(description: "Eintrittskarte Deutsches Museum", tags: ["Reise", "Kultur"], latitude: 48.1299, longitude: 11.5833, address: "Deutsches Museum, München"),
                    "it": LocaleContent(description: "Biglietto Galleria degli Uffizi", tags: ["viaggio", "cultura"], latitude: 43.7677, longitude: 11.2553, address: "Galleria degli Uffizi, Firenze"),
                    "ja": LocaleContent(description: "東京国立博物館チケット", tags: ["旅行", "文化"], latitude: 35.7189, longitude: 139.7766, address: "上野公園, 東京"),
                    "ko": LocaleContent(description: "국립중앙박물관 티켓", tags: ["여행", "문화"], latitude: 37.5239, longitude: 126.9804, address: "국립중앙박물관, 서울"),
                    "zh-Hans": LocaleContent(description: "故宫博物院门票", tags: ["旅行", "文化"], latitude: 39.9163, longitude: 116.3972, address: "故宫博物院, 北京"),
                    "zh-Hant": LocaleContent(description: "國立故宮博物院門票", tags: ["旅行", "文化"], latitude: 25.1024, longitude: 121.5485, address: "國立故宮博物院, 台北"),
                ]
            ),
            (
                BarcodeSkeleton(
                    rawValue: "1234567890128",
                    type: .ean13,
                    hoursAgo: 171
                ),
                [
                    "en": LocaleContent(description: "Trader Joe's trail mix", tags: ["grocery"], latitude: 47.6062, longitude: -122.3321, address: "Pike Place Market, Seattle, WA"),
                    "es": LocaleContent(description: "Mezcla de frutos secos Hacendado", tags: ["supermercado"], latitude: 42.2406, longitude: -8.7207, address: "Casco Vello, Vigo"),
                    "fr": LocaleContent(description: "Mélange de fruits secs Monoprix", tags: ["courses"], latitude: 48.2478, longitude: -4.4914, address: "Presqu'île de Crozon, Finistère"),
                    "pt": LocaleContent(description: "Mix de castanhas Pão de Açúcar", tags: ["mercado"], latitude: -8.0476, longitude: -34.8770, address: "Recife Antigo, Recife"),
                    "de": LocaleContent(description: "Studentenfutter dm", tags: ["Einkauf"], latitude: 53.5511, longitude: 9.9937, address: "Jungfernstieg, Hamburg"),
                    "it": LocaleContent(description: "Mix di frutta secca Ferrara", tags: ["spesa"], latitude: 37.0755, longitude: 15.2866, address: "Mercato di Ortigia, Siracusa"),
                    "ja": LocaleContent(description: "ローソン ミックスナッツ", tags: ["食料品"], latitude: 35.0050, longitude: 135.7631, address: "錦市場, 京都"),
                    "ko": LocaleContent(description: "이마트 믹스넛", tags: ["식료품"], latitude: 33.4507, longitude: 126.5706, address: "동문시장, 제주"),
                    "zh-Hans": LocaleContent(description: "盒马鲜生每日坚果", tags: ["食品"], latitude: 23.1291, longitude: 113.2644, address: "北京路步行街, 广州"),
                    "zh-Hant": LocaleContent(description: "全聯福利中心每日堅果", tags: ["食品"], latitude: 22.0025, longitude: 120.7445, address: "恆春老街, 屏東"),
                ]
            ),
            (
                BarcodeSkeleton(
                    rawValue: "https://example.com/receipt/9281",
                    type: .qr,
                    hoursAgo: 192
                ),
                [
                    "en": LocaleContent(description: "Target digital receipt", tags: []),
                    "es": LocaleContent(description: "Ticket de compra digital El Corte Inglés", tags: []),
                    "fr": LocaleContent(description: "Ticket de caisse Carrefour", tags: []),
                    "pt": LocaleContent(description: "Cupom fiscal digital Casas Bahia", tags: []),
                    "de": LocaleContent(description: "Digitaler Kassenbon REWE", tags: []),
                    "it": LocaleContent(description: "Scontrino digitale Esselunga", tags: []),
                    "ja": LocaleContent(description: "ドン・キホーテ デジタルレシート", tags: []),
                    "ko": LocaleContent(description: "쿠팡 디지털 영수증", tags: []),
                    "zh-Hans": LocaleContent(description: "京东电子收据", tags: []),
                    "zh-Hant": LocaleContent(description: "全家便利商店電子發票", tags: []),
                ]
            ),

            // Generated barcodes
            (
                BarcodeSkeleton(
                    rawValue: "https://github.com",
                    type: .qr,
                    hoursAgo: 4,
                    isGenerated: true
                ),
                [
                    "en": LocaleContent(description: "GitHub homepage", tags: ["web"]),
                    "es": LocaleContent(description: "Página de inicio de GitHub", tags: ["web"]),
                    "fr": LocaleContent(description: "Page d'accueil GitHub", tags: ["web"]),
                    "pt": LocaleContent(description: "Página inicial do GitHub", tags: ["web"]),
                    "de": LocaleContent(description: "GitHub-Startseite", tags: ["Web"]),
                    "it": LocaleContent(description: "Pagina iniziale GitHub", tags: ["web"]),
                    "ja": LocaleContent(description: "GitHubホームページ", tags: ["ウェブ"]),
                    "ko": LocaleContent(description: "GitHub 홈페이지", tags: ["웹"]),
                    "zh-Hans": LocaleContent(description: "GitHub主页", tags: ["网站"]),
                    "zh-Hant": LocaleContent(description: "GitHub首頁", tags: ["網站"]),
                ]
            ),
            (
                BarcodeSkeleton(
                    rawValue: "0071660309046",
                    type: .ean13,
                    hoursAgo: 48,
                    isGenerated: true
                ),
                [
                    "en": LocaleContent(description: "Custom product label", tags: []),
                    "es": LocaleContent(description: "Etiqueta de producto personalizada", tags: []),
                    "fr": LocaleContent(description: "Étiquette produit personnalisée", tags: []),
                    "pt": LocaleContent(description: "Etiqueta de produto personalizada", tags: []),
                    "de": LocaleContent(description: "Individuelles Produktetikett", tags: []),
                    "it": LocaleContent(description: "Etichetta prodotto personalizzata", tags: []),
                    "ja": LocaleContent(description: "カスタム商品ラベル", tags: []),
                    "ko": LocaleContent(description: "커스텀 상품 라벨", tags: []),
                    "zh-Hans": LocaleContent(description: "自定义商品标签", tags: []),
                    "zh-Hant": LocaleContent(description: "自訂商品標籤", tags: []),
                ]
            ),
        ]

        // MARK: - Skeleton

        private struct BarcodeSkeleton {
            let rawValue: String
            let type: BarcodeType
            let hoursAgo: Double
            let isFavorite: Bool
            let isGenerated: Bool

            init(
                rawValue: String,
                type: BarcodeType,
                hoursAgo: Double,
                isFavorite: Bool = false,
                isGenerated: Bool = false
            ) {
                self.rawValue = rawValue
                self.type = type
                self.hoursAgo = hoursAgo
                self.isFavorite = isFavorite
                self.isGenerated = isGenerated
            }
        }

        // MARK: - Seed

        static func seed(into context: ModelContext) {
            let lang = resolvedLanguage()

            for (skeleton, locales) in entries {
                let content = locales[lang] ?? locales["en"]!

                let barcode = ScannedBarcode(
                    rawValue: skeleton.rawValue,
                    type: skeleton.type,
                    latitude: content.latitude,
                    longitude: content.longitude,
                    barcodeDescription: content.description,
                    timestamp: Date.now - skeleton.hoursAgo * 3600,
                    isFavorite: skeleton.isFavorite,
                    tags: content.tags,
                    address: content.address,
                    isGenerated: skeleton.isGenerated
                )
                context.insert(barcode)
            }
            try? context.save()
        }

        /// Resolves the current app language to a key in the locale maps.
        /// Tries exact match, then language-script prefix, then language-only prefix.
        private static func resolvedLanguage() -> String {
            guard let preferred = Locale.preferredLanguages.first else { return "en" }

            // Exact match (e.g. "en-US")
            if entries.first?.locales[preferred] != nil { return preferred }

            // Script-qualified prefix (e.g. "zh-Hans" from "zh-Hans-CN")
            let parts = preferred.split(separator: "-")
            if parts.count >= 2 {
                let langScript = "\(parts[0])-\(parts[1])"
                if entries.first?.locales[langScript] != nil { return langScript }
            }

            // Language-only prefix (e.g. "fr" from "fr-FR")
            let langOnly = String(parts[0])
            if entries.first?.locales[langOnly] != nil { return langOnly }

            return "en"
        }
    }
#endif
