import Foundation

/// Object used for sending anonymous statistics about ObjectBox usage.
/// Keep data sparsity and abuse potential in mind before you add anything to this.
class BuildTracker {
    var verbose: Bool = false
    var statistics: Bool = true

    /// Key under which we save the UUID identifying this installation as a string to preferences.
    private static let installationIDDefaultsKey = "OBXInstallationID"
    /// Key under which we save the number of builds since last successful send to preferences.
    private static let buildCountDefaultsKey = "OBXBuildCount"
    /// Key under which we save the time of last successful send to preferences so we don't send more often than daily.
    private static let lastSuccessfulSendTimeDefaultsKey = "OBXLastSuccessfulSendTime"
    
    /// Send at most once per day, but use 23 hours so we don't skip a day on a DST change or early work start:
    private static let hoursBetweenBuildMessages = TimeInterval(23.0)
    /// 1 hour expressed in seconds:
    private static let hourInSeconds = TimeInterval(3600.0)
    /// Base URL we append our tracking data to to send it out:
    private static let baseURL = "https://api.mixpanel.com/track/?data="
    /// Token to include with all events:
    private static let eventToken = "46d62a7c8def175e66900b3da09d698c"

    /// Build a JSON string containing the information we send to Mixpanel.
    func eventDictionary(name: String, uniqueID: String? = nil, properties: [String: Any] = [:]) -> [String: Any] {
        let locale = Locale.current
        let country = BuildTracker.countryMappings[locale.regionCode?.uppercased() ?? ""] ?? ""
        let language = BuildTracker.languageMappings[locale.languageCode?.lowercased() ?? ""] ?? ""
        
        var eventInfo = [String: Any]()
        var eventProperties = [String: Any]()
        eventInfo["event"] = name
        eventProperties["token"] = BuildTracker.eventToken
        eventProperties["Tool"] = "Sourcery"
        eventProperties["c"] = country
        eventProperties["lang"] = language
        if let uniqueID = uniqueID {
            eventProperties["distinct_id"] = uniqueID
        }
        eventProperties.merge(properties) { _, new in return new } // Merge, preferring new value if both are set.
        eventInfo["properties"] = eventProperties
        return eventInfo
    }
    
    /// Build a URL request for the given properties, unique ID and event name and send them out asynchronously.
    func sendEvent(name: String, uniqueID: String? = nil, properties: [String: Any] = [:]) throws {
        // Attach statistics to URL:
        let eventInfoDict = eventDictionary(name: name, uniqueID: uniqueID, properties: properties)
        var options: JSONSerialization.WritingOptions = []
        if #available(OSX 10.15, *) {
            options.insert(.withoutEscapingSlashes)
        }
        let eventInfo = try JSONSerialization.data(withJSONObject: eventInfoDict, options: options)
        var urlString = BuildTracker.baseURL
        let base64EncodedProperties = eventInfo.base64EncodedString()
        guard base64EncodedProperties.count > 0 else {
            print("warning: Couldn't base64-encode statistics. This does not affect your generated code.")
            return
        }
        urlString.append(base64EncodedProperties)
        
        if verbose {
            print("Trying to send statistics: <<\(String(data: eventInfo, encoding: .utf8) ?? "")>>")
        }
        
        // Actually send them off:
        let task = URLSession.shared.dataTask(with: URL(string: urlString)!) { data, response, error in
            guard error == nil, let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                if self.verbose {
                    print("warning: Couldn't send statistics: \((response as? HTTPURLResponse)?.statusCode ?? 0) "
                        + "\(error?.localizedDescription ?? "<no error description>"). "
                        + "This does not affect your generated code.")
                }
                return
            }
            
            // Successfully sent? Reset counter and remember when we last sent so we don't call home too often:
            UserDefaults.standard.set(0, forKey: BuildTracker.buildCountDefaultsKey)
            UserDefaults.standard.set(Date().timeIntervalSinceReferenceDate, forKey: BuildTracker.lastSuccessfulSendTimeDefaultsKey)
            
            if self.verbose {
                print("Successfully sent statistics.")
            }
        }
        task.resume()
    }
    
    /// Return a string identifying any CI system we may be running under right now.
    func checkCI() -> String? {
        // https://docs.travis-ci.com/user/environment-variables/#Default-Environment-Variables
        if ProcessInfo.processInfo.environment["CI"] == "true" {
            return "T"
            // https://wiki.jenkins.io/display/JENKINS/Building+a+software+project#Buildingasoftwareproject-below
        } else if ProcessInfo.processInfo.environment["JENKINS_URL"] != nil {
            return "J"
            // https://docs.gitlab.com/ee/ci/variables/
        } else if ProcessInfo.processInfo.environment["GITLAB_CI"] != nil {
            return "GL"
            // https://circleci.com/docs/1.0/environment-variables/
        } else if ProcessInfo.processInfo.environment["CIRCLECI"] != nil {
            return "C"
            // https://documentation.codeship.com/pro/builds-and-configuration/steps/
        } else if ProcessInfo.processInfo.environment["CI_NAME"]?.lowercased() == "codeship" {
            return "CS"
        } else if ProcessInfo.processInfo.environment["CI"] != nil {
            return "Other"
        }
        
        return nil
    }
    
    /// Send the build statistics request at startup, unless user asked not to:
    func startup() throws {
        if statistics {
            var buildCount = (UserDefaults.standard.object(forKey: BuildTracker.buildCountDefaultsKey) as? Int) ?? 0
            buildCount += 1
            UserDefaults.standard.set(buildCount, forKey: BuildTracker.buildCountDefaultsKey)
            
            let lastSuccessfulSendTime = UserDefaults.standard.double(forKey: BuildTracker.lastSuccessfulSendTimeDefaultsKey)
            let nowSeconds = Date().timeIntervalSinceReferenceDate
            let timeSinceLastSend = nowSeconds - lastSuccessfulSendTime
            let minTimeBetweenSends = BuildTracker.hourInSeconds * BuildTracker.hoursBetweenBuildMessages
            guard timeSinceLastSend > minTimeBetweenSends else { return }
            
            // Give installation a unique identifier so we can get a rough idea of how many people use this:
            let existingInstallationID = UserDefaults.standard.string(forKey: BuildTracker.installationIDDefaultsKey)
            let installationUID = existingInstallationID ?? UUID().uuidString
            if existingInstallationID == nil {
                UserDefaults.standard.set(installationUID, forKey: BuildTracker.installationIDDefaultsKey)
            }
            
            // Grab some info from Xcode-set environment variables, if available:
            let minSysVersion: String
            if let deploymentTargetVarName = ProcessInfo.processInfo.environment["DEPLOYMENT_TARGET_CLANG_ENV_NAME"] {
                minSysVersion = ProcessInfo.processInfo.environment[deploymentTargetVarName] ?? ""
            } else {
                minSysVersion = ""
            }
            let architectures = ProcessInfo.processInfo.environment["ARCHS"] ?? ""
            let moduleName = ProcessInfo.processInfo.environment["PRODUCT_MODULE_NAME"] ?? ""
            let destPlatform = ProcessInfo.processInfo.environment["SDK_NAME"] ?? ""
            let version = ProcessInfo.processInfo.operatingSystemVersion
            let xcodeVersion = ProcessInfo.processInfo.environment["XCODE_VERSION_ACTUAL"] ?? ""
            let myVersion = Sourcery.version
            
            var properties: [String: Any] = [
                "BuildOS": "macOS",
                "BuildOSVersion": "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)",
                "BuildCount": buildCount,
                "AppHash": moduleName.sha1(),
                "Platform": destPlatform,
                "Architectures": architectures,
                "MinimumOSVersion": minSysVersion,
                "Xcode": xcodeVersion,
                "Version": myVersion
                ]
            
            if let ci = checkCI() {
                properties["CI"] = ci
            }
            
            try sendEvent(name: "Build", uniqueID: installationUID, properties: properties)
        }
    }

    /// Allow mapping from 2-character to 3-character country codes.
    /// (ISO 3166-1)
    private static let countryMappings = [
        "AF": "AFG", //  Afghanistan
        "AX": "ALA", //  Åland Islands
        "AL": "ALB", //  Albania
        "DZ": "DZA", //  Algeria
        "AS": "ASM", //  American Samoa
        "AD": "AND", //  Andorra
        "AO": "AGO", //  Angola
        "AI": "AIA", //  Anguilla
        "AQ": "ATA", //  Antarctica
        "AG": "ATG", //  Antigua and Barbuda
        "AR": "ARG", //  Argentina
        "AM": "ARM", //  Armenia
        "AW": "ABW", //  Aruba
        "AU": "AUS", //  Australia
        "AT": "AUT", //  Austria
        "AZ": "AZE", //  Azerbaijan
        "BS": "BHS", //  Bahamas
        "BH": "BHR", //  Bahrain
        "BD": "BGD", //  Bangladesh
        "BB": "BRB", //  Barbados
        "BY": "BLR", //  Belarus
        "BE": "BEL", //  Belgium
        "BZ": "BLZ", //  Belize
        "BJ": "BEN", //  Benin
        "BM": "BMU", //  Bermuda
        "BT": "BTN", //  Bhutan
        "BO": "BOL", //  Bolivia (Plurinational State of)
        "BQ": "BES", //  Bonaire, Sint Eustatius and Saba
        "BA": "BIH", //  Bosnia and Herzegovina
        "BW": "BWA", //  Botswana
        "BV": "BVT", //  Bouvet Island
        "BR": "BRA", //  Brazil
        "IO": "IOT", //  British Indian Ocean Territory
        "BN": "BRN", //  Brunei Darussalam
        "BG": "BGR", //  Bulgaria
        "BF": "BFA", //  Burkina Faso
        "BI": "BDI", //  Burundi
        "CV": "CPV", //  Cabo Verde
        "KH": "KHM", //  Cambodia
        "CM": "CMR", //  Cameroon
        "CA": "CAN", //  Canada
        "KY": "CYM", //  Cayman Islands
        "CF": "CAF", //  Central African Republic
        "TD": "TCD", //  Chad
        "CL": "CHL", //  Chile
        "CN": "CHN", //  China
        "CX": "CXR", //  Christmas Island
        "CC": "CCK", //  Cocos (Keeling) Islands
        "CO": "COL", //  Colombia
        "KM": "COM", //  Comoros
        "CG": "COG", //  Congo
        "CD": "COD", //  Congo, Democratic Republic of the
        "CK": "COK", //  Cook Islands
        "CR": "CRI", //  Costa Rica
        "CI": "CIV", //  Côte d'Ivoire
        "HR": "HRV", //  Croatia
        "CU": "CUB", //  Cuba
        "CW": "CUW", //  Curaçao
        "CY": "CYP", //  Cyprus
        "CZ": "CZE", //  Czechia
        "DK": "DNK", //  Denmark
        "DJ": "DJI", //  Djibouti
        "DM": "DMA", //  Dominica
        "DO": "DOM", //  Dominican Republic
        "EC": "ECU", //  Ecuador
        "EG": "EGY", //  Egypt
        "SV": "SLV", //  El Salvador
        "GQ": "GNQ", //  Equatorial Guinea
        "ER": "ERI", //  Eritrea
        "EE": "EST", //  Estonia
        "SZ": "SWZ", //  Eswatini
        "ET": "ETH", //  Ethiopia
        "FK": "FLK", //  Falkland Islands (Malvinas)
        "FO": "FRO", //  Faroe Islands
        "FJ": "FJI", //  Fiji
        "FI": "FIN", //  Finland
        "FR": "FRA", //  France
        "GF": "GUF", //  French Guiana
        "PF": "PYF", //  French Polynesia
        "TF": "ATF", //  French Southern Territories
        "GA": "GAB", //  Gabon
        "GM": "GMB", //  Gambia
        "GE": "GEO", //  Georgia
        "DE": "DEU", //  Germany
        "GH": "GHA", //  Ghana
        "GI": "GIB", //  Gibraltar
        "GR": "GRC", //  Greece
        "GL": "GRL", //  Greenland
        "GD": "GRD", //  Grenada
        "GP": "GLP", //  Guadeloupe
        "GU": "GUM", //  Guam
        "GT": "GTM", //  Guatemala
        "GG": "GGY", //  Guernsey
        "GN": "GIN", //  Guinea
        "GW": "GNB", //  Guinea-Bissau
        "GY": "GUY", //  Guyana
        "HT": "HTI", //  Haiti
        "HM": "HMD", //  Heard Island and McDonald Islands
        "VA": "VAT", //  Holy See
        "HN": "HND", //  Honduras
        "HK": "HKG", //  Hong Kong
        "HU": "HUN", //  Hungary
        "IS": "ISL", //  Iceland
        "IN": "IND", //  India
        "ID": "IDN", //  Indonesia
        "IR": "IRN", //  Iran (Islamic Republic of)
        "IQ": "IRQ", //  Iraq
        "IE": "IRL", //  Ireland
        "IM": "IMN", //  Isle of Man
        "IL": "ISR", //  Israel
        "IT": "ITA", //  Italy
        "JM": "JAM", //  Jamaica
        "JP": "JPN", //  Japan
        "JE": "JEY", //  Jersey
        "JO": "JOR", //  Jordan
        "KZ": "KAZ", //  Kazakhstan
        "KE": "KEN", //  Kenya
        "KI": "KIR", //  Kiribati
        "KP": "PRK", //  Korea (Democratic People's Republic of)
        "KR": "KOR", //  Korea, Republic of
        "KW": "KWT", //  Kuwait
        "KG": "KGZ", //  Kyrgyzstan
        "LA": "LAO", //  Lao People's Democratic Republic
        "LV": "LVA", //  Latvia
        "LB": "LBN", //  Lebanon
        "LS": "LSO", //  Lesotho
        "LR": "LBR", //  Liberia
        "LY": "LBY", //  Libya
        "LI": "LIE", //  Liechtenstein
        "LT": "LTU", //  Lithuania
        "LU": "LUX", //  Luxembourg
        "MO": "MAC", //  Macao
        "MG": "MDG", //  Madagascar
        "MW": "MWI", //  Malawi
        "MY": "MYS", //  Malaysia
        "MV": "MDV", //  Maldives
        "ML": "MLI", //  Mali
        "MT": "MLT", //  Malta
        "MH": "MHL", //  Marshall Islands
        "MQ": "MTQ", //  Martinique
        "MR": "MRT", //  Mauritania
        "MU": "MUS", //  Mauritius
        "YT": "MYT", //  Mayotte
        "MX": "MEX", //  Mexico
        "FM": "FSM", //  Micronesia (Federated States of)
        "MD": "MDA", //  Moldova, Republic of
        "MC": "MCO", //  Monaco
        "MN": "MNG", //  Mongolia
        "ME": "MNE", //  Montenegro
        "MS": "MSR", //  Montserrat
        "MA": "MAR", //  Morocco
        "MZ": "MOZ", //  Mozambique
        "MM": "MMR", //  Myanmar
        "NA": "NAM", //  Namibia
        "NR": "NRU", //  Nauru
        "NP": "NPL", //  Nepal
        "NL": "NLD", //  Netherlands
        "NC": "NCL", //  New Caledonia
        "NZ": "NZL", //  New Zealand
        "NI": "NIC", //  Nicaragua
        "NE": "NER", //  Niger
        "NG": "NGA", //  Nigeria
        "NU": "NIU", //  Niue
        "NF": "NFK", //  Norfolk Island
        "MK": "MKD", //  North Macedonia
        "MP": "MNP", //  Northern Mariana Islands
        "NO": "NOR", //  Norway
        "OM": "OMN", //  Oman
        "PK": "PAK", //  Pakistan
        "PW": "PLW", //  Palau
        "PS": "PSE", //  Palestine, State of
        "PA": "PAN", //  Panama
        "PG": "PNG", //  Papua New Guinea
        "PY": "PRY", //  Paraguay
        "PE": "PER", //  Peru
        "PH": "PHL", //  Philippines
        "PN": "PCN", //  Pitcairn
        "PL": "POL", //  Poland
        "PT": "PRT", //  Portugal
        "PR": "PRI", //  Puerto Rico
        "QA": "QAT", //  Qatar
        "RE": "REU", //  Réunion
        "RO": "ROU", //  Romania
        "RU": "RUS", //  Russian Federation
        "RW": "RWA", //  Rwanda
        "BL": "BLM", //  Saint Barthélemy
        "SH": "SHN", //  Saint Helena, Ascension and Tristan da Cunha
        "KN": "KNA", //  Saint Kitts and Nevis
        "LC": "LCA", //  Saint Lucia
        "MF": "MAF", //  Saint Martin (French part)
        "PM": "SPM", //  Saint Pierre and Miquelon
        "VC": "VCT", //  Saint Vincent and the Grenadines
        "WS": "WSM", //  Samoa
        "SM": "SMR", //  San Marino
        "ST": "STP", //  Sao Tome and Principe
        "SA": "SAU", //  Saudi Arabia
        "SN": "SEN", //  Senegal
        "RS": "SRB", //  Serbia
        "SC": "SYC", //  Seychelles
        "SL": "SLE", //  Sierra Leone
        "SG": "SGP", //  Singapore
        "SX": "SXM", //  Sint Maarten (Dutch part)
        "SK": "SVK", //  Slovakia
        "SI": "SVN", //  Slovenia
        "SB": "SLB", //  Solomon Islands
        "SO": "SOM", //  Somalia
        "ZA": "ZAF", //  South Africa
        "GS": "SGS", //  South Georgia and the South Sandwich Islands
        "SS": "SSD", //  South Sudan
        "ES": "ESP", //  Spain
        "LK": "LKA", //  Sri Lanka
        "SD": "SDN", //  Sudan
        "SR": "SUR", //  Suriname
        "SJ": "SJM", //  Svalbard and Jan Mayen
        "SE": "SWE", //  Sweden
        "CH": "CHE", //  Switzerland
        "SY": "SYR", //  Syrian Arab Republic
        "TW": "TWN", //  Taiwan, Province of China[a]
        "TJ": "TJK", //  Tajikistan
        "TZ": "TZA", //  Tanzania, United Republic of
        "TH": "THA", //  Thailand
        "TL": "TLS", //  Timor-Leste
        "TG": "TGO", //  Togo
        "TK": "TKL", //  Tokelau
        "TO": "TON", //  Tonga
        "TT": "TTO", //  Trinidad and Tobago
        "TN": "TUN", //  Tunisia
        "TR": "TUR", //  Turkey
        "TM": "TKM", //  Turkmenistan
        "TC": "TCA", //  Turks and Caicos Islands
        "TV": "TUV", //  Tuvalu
        "UG": "UGA", //  Uganda
        "UA": "UKR", //  Ukraine
        "AE": "ARE", //  United Arab Emirates
        "GB": "GBR", //  United Kingdom of Great Britain and Northern Ireland
        "US": "USA", //  United States of America
        "UM": "UMI", //  United States Minor Outlying Islands
        "UY": "URY", //  Uruguay
        "UZ": "UZB", //  Uzbekistan
        "VU": "VUT", //  Vanuatu
        "VE": "VEN", //  Venezuela (Bolivarian Republic of)
        "VN": "VNM", //  Viet Nam
        "VG": "VGB", //  Virgin Islands (British)
        "VI": "VIR", //  Virgin Islands (U.S.)
        "WF": "WLF", //  Wallis and Futuna
        "EH": "ESH", //  Western Sahara
        "YE": "YEM", //  Yemen
        "ZM": "ZMB", //  Zambia
        "ZW": "ZWE" //  Zimbabwe
    ]
    /// Allow mapping from 2-character to 3-character language codes.
    /// (ISO 639-2)
    private static let languageMappings = [
        "ab": "abk", // Abkhazian
        "aa": "aar", // Afar
        "af": "afr", // Afrikaans
        "ak": "aka", // Akan
        "sq": "sqi", // Albanian
        "am": "amh", // Amharic
        "ar": "ara", // Arabic
        "an": "arg", // Aragonese
        "hy": "hye", // Armenian
        "as": "asm", // Assamese
        "av": "ava", // Avaric
        "ae": "ave", // Avestan
        "ay": "aym", // Aymara
        "az": "aze", // Azerbaijani
        "bm": "bam", // Bambara
        "ba": "bak", // Bashkir
        "eu": "eus", // Basque
        "be": "bel", // Belarusian
        "bn": "ben", // Bengali
        "bh": "bih", // Bihari languages
        "bi": "bis", // Bislama
        "bs": "bos", // Bosnian
        "br": "bre", // Breton
        "bg": "bul", // Bulgarian
        "my": "mya", // Burmese
        "ca": "cat", // Catalan, Valencian
        "ch": "cha", // Chamorro
        "ce": "che", // Chechen
        "ny": "nya", // Chichewa, Chewa, Nyanja
        "zh": "zho", // Chinese
        "cv": "chv", // Chuvash
        "kw": "cor", // Cornish
        "co": "cos", // Corsican
        "cr": "cre", // Cree
        "hr": "hrv", // Croatian
        "cs": "ces", // Czech
        "da": "dan", // Danish
        "dv": "div", // Divehi, Dhivehi, Maldivian
        "nl": "nld", // Dutch, Flemish
        "dz": "dzo", // Dzongkha
        "en": "eng", // English
        "eo": "epo", // Esperanto
        "et": "est", // Estonian
        "ee": "ewe", // Ewe
        "fo": "fao", // Faroese
        "fj": "fij", // Fijian
        "fi": "fin", // Finnish
        "fr": "fra", // French
        "ff": "ful", // Fulah
        "gl": "glg", // Galician
        "ka": "kat", // Georgian
        "de": "deu", // German
        "el": "ell", // Greek, Modern (1453-)
        "gn": "grn", // Guarani
        "gu": "guj", // Gujarati
        "ht": "hat", // Haitian, Haitian Creole
        "ha": "hau", // Hausa
        "he": "heb", // Hebrew
        "hz": "her", // Herero
        "hi": "hin", // Hindi
        "ho": "hmo", // Hiri Motu
        "hu": "hun", // Hungarian
        "ia": "ina", // Interlingua (International Auxiliary Language Association)
        "id": "ind", // Indonesian
        "ie": "ile", // Interlingue, Occidental
        "ga": "gle", // Irish
        "ig": "ibo", // Igbo
        "ik": "ipk", // Inupiaq
        "io": "ido", // Ido
        "is": "isl", // Icelandic
        "it": "ita", // Italian
        "iu": "iku", // Inuktitut
        "ja": "jpn", // Japanese
        "jv": "jav", // Javanese
        "kl": "kal", // Kalaallisut, Greenlandic
        "kn": "kan", // Kannada
        "kr": "kau", // Kanuri
        "ks": "kas", // Kashmiri
        "kk": "kaz", // Kazakh
        "km": "khm", // Central Khmer
        "ki": "kik", // Kikuyu, Gikuyu
        "rw": "kin", // Kinyarwanda
        "ky": "kir", // Kirghiz, Kyrgyz
        "kv": "kom", // Komi
        "kg": "kon", // Kongo
        "ko": "kor", // Korean
        "ku": "kur", // Kurdish
        "kj": "kua", // Kuanyama, Kwanyama
        "la": "lat", // Latin
        "lb": "ltz", // Luxembourgish, Letzeburgesch
        "lg": "lug", // Ganda
        "li": "lim", // Limburgan, Limburger, Limburgish
        "ln": "lin", // Lingala
        "lo": "lao", // Lao
        "lt": "lit", // Lithuanian
        "lu": "lub", // Luba-Katanga
        "lv": "lav", // Latvian
        "gv": "glv", // Manx
        "mk": "mkd", // Macedonian
        "mg": "mlg", // Malagasy
        "ms": "msa", // Malay
        "ml": "mal", // Malayalam
        "mt": "mlt", // Maltese
        "mi": "mri", // Maori
        "mr": "mar", // Marathi
        "mh": "mah", // Marshallese
        "mn": "mon", // Mongolian
        "na": "nau", // Nauru
        "nv": "nav", // Navajo, Navaho
        "nd": "nde", // North Ndebele
        "ne": "nep", // Nepali
        "ng": "ndo", // Ndonga
        "nb": "nob", // Norwegian Bokml
        "nn": "nno", // Norwegian Nynorsk
        "no": "nor", // Norwegian
        "ii": "iii", // Sichuan Yi, Nuosu
        "nr": "nbl", // South Ndebele
        "oc": "oci", // Occitan
        "oj": "oji", // Ojibwa
        "cu": "chu", // Church Slavic, Old Slavonic, Church Slavonic, Old Bulgarian, Old Church Slavonic
        "om": "orm", // Oromo
        "or": "ori", // Oriya
        "os": "oss", // Ossetian, Ossetic
        "pa": "pan", // Punjabi, Panjabi
        "pi": "pli", // Pali
        "fa": "fas", // Persian
        "pl": "pol", // Polish
        "ps": "pus", // Pashto, Pushto
        "pt": "por", // Portuguese
        "qu": "que", // Quechua
        "rm": "roh", // Romansh
        "rn": "run", // Rundi
        "ro": "ron", // Romanian, Moldavian, Moldovan
        "ru": "rus", // Russian
        "sa": "san", // Sanskrit
        "sc": "srd", // Sardinian
        "sd": "snd", // Sindhi
        "se": "sme", // Northern Sami
        "sm": "smo", // Samoan
        "sg": "sag", // Sango
        "sr": "srp", // Serbian
        "gd": "gla", // Gaelic, Scottish Gaelic
        "sn": "sna", // Shona
        "si": "sin", // Sinhala, Sinhalese
        "sk": "slk", // Slovak
        "sl": "slv", // Slovenian
        "so": "som", // Somali
        "st": "sot", // Southern Sotho
        "es": "spa", // Spanish, Castilian
        "su": "sun", // Sundanese
        "sw": "swa", // Swahili
        "ss": "ssw", // Swati
        "sv": "swe", // Swedish
        "ta": "tam", // Tamil
        "te": "tel", // Telugu
        "tg": "tgk", // Tajik
        "th": "tha", // Thai
        "ti": "tir", // Tigrinya
        "bo": "bod", // Tibetan
        "tk": "tuk", // Turkmen
        "tl": "tgl", // Tagalog
        "tn": "tsn", // Tswana
        "to": "ton", // Tonga (Tonga Islands)
        "tr": "tur", // Turkish
        "ts": "tso", // Tsonga
        "tt": "tat", // Tatar
        "tw": "twi", // Twi
        "ty": "tah", // Tahitian
        "ug": "uig", // Uighur, Uyghur
        "uk": "ukr", // Ukrainian
        "ur": "urd", // Urdu
        "uz": "uzb", // Uzbek
        "ve": "ven", // Venda
        "vi": "vie", // Vietnamese
        "vo": "vol", // Volapk
        "wa": "wln", // Walloon
        "cy": "cym", // Welsh
        "wo": "wol", // Wolof
        "fy": "fry", // Western Frisian
        "xh": "xho", // Xhosa
        "yi": "yid", // Yiddish
        "yo": "yor", // Yoruba
        "za": "zha", // Zhuang, Chuang
        "zu": "zul" // Zulu
    ]
}
