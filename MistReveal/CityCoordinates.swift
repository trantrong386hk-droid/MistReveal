import CoreLocation

/// 中国主要城市坐标字典 + 近似坐标生成
struct CityCoordinates {

    struct CityInfo {
        let name: String
        let coordinate: CLLocationCoordinate2D
    }

    static let cities: [CityInfo] = [
        // 直辖市
        CityInfo(name: "北京", coordinate: CLLocationCoordinate2D(latitude: 39.9042, longitude: 116.4074)),
        CityInfo(name: "上海", coordinate: CLLocationCoordinate2D(latitude: 31.2304, longitude: 121.4737)),
        CityInfo(name: "天津", coordinate: CLLocationCoordinate2D(latitude: 39.0842, longitude: 117.2010)),
        CityInfo(name: "重庆", coordinate: CLLocationCoordinate2D(latitude: 29.5630, longitude: 106.5516)),
        // 广东
        CityInfo(name: "广州", coordinate: CLLocationCoordinate2D(latitude: 23.1291, longitude: 113.2644)),
        CityInfo(name: "深圳", coordinate: CLLocationCoordinate2D(latitude: 22.5431, longitude: 114.0579)),
        CityInfo(name: "东莞", coordinate: CLLocationCoordinate2D(latitude: 23.0207, longitude: 113.7518)),
        CityInfo(name: "佛山", coordinate: CLLocationCoordinate2D(latitude: 23.0218, longitude: 113.1219)),
        CityInfo(name: "珠海", coordinate: CLLocationCoordinate2D(latitude: 22.2710, longitude: 113.5767)),
        // 广东（续）
        CityInfo(name: "汕头", coordinate: CLLocationCoordinate2D(latitude: 23.3541, longitude: 116.6820)),
        CityInfo(name: "揭阳", coordinate: CLLocationCoordinate2D(latitude: 23.5498, longitude: 116.3728)),
        CityInfo(name: "潮州", coordinate: CLLocationCoordinate2D(latitude: 23.6567, longitude: 116.6226)),
        CityInfo(name: "梅州", coordinate: CLLocationCoordinate2D(latitude: 24.2888, longitude: 116.1224)),
        CityInfo(name: "汕尾", coordinate: CLLocationCoordinate2D(latitude: 22.7748, longitude: 115.3750)),
        // 江苏
        CityInfo(name: "南京", coordinate: CLLocationCoordinate2D(latitude: 32.0603, longitude: 118.7969)),
        CityInfo(name: "苏州", coordinate: CLLocationCoordinate2D(latitude: 31.2989, longitude: 120.5853)),
        CityInfo(name: "无锡", coordinate: CLLocationCoordinate2D(latitude: 31.4912, longitude: 120.3119)),
        CityInfo(name: "南通", coordinate: CLLocationCoordinate2D(latitude: 31.9802, longitude: 120.8944)),
        // 浙江
        CityInfo(name: "杭州", coordinate: CLLocationCoordinate2D(latitude: 30.2741, longitude: 120.1551)),
        CityInfo(name: "宁波", coordinate: CLLocationCoordinate2D(latitude: 29.8683, longitude: 121.5440)),
        CityInfo(name: "温州", coordinate: CLLocationCoordinate2D(latitude: 28.0000, longitude: 120.6722)),
        // 四川
        CityInfo(name: "成都", coordinate: CLLocationCoordinate2D(latitude: 30.5728, longitude: 104.0668)),
        CityInfo(name: "绵阳", coordinate: CLLocationCoordinate2D(latitude: 31.4678, longitude: 104.6796)),
        // 湖北
        CityInfo(name: "武汉", coordinate: CLLocationCoordinate2D(latitude: 30.5928, longitude: 114.3055)),
        // 湖南
        CityInfo(name: "长沙", coordinate: CLLocationCoordinate2D(latitude: 28.2282, longitude: 112.9388)),
        // 陕西
        CityInfo(name: "西安", coordinate: CLLocationCoordinate2D(latitude: 34.3416, longitude: 108.9398)),
        // 福建
        CityInfo(name: "福州", coordinate: CLLocationCoordinate2D(latitude: 26.0745, longitude: 119.2965)),
        CityInfo(name: "厦门", coordinate: CLLocationCoordinate2D(latitude: 24.4798, longitude: 118.0894)),
        // 山东
        CityInfo(name: "济南", coordinate: CLLocationCoordinate2D(latitude: 36.6512, longitude: 117.1201)),
        CityInfo(name: "青岛", coordinate: CLLocationCoordinate2D(latitude: 36.0671, longitude: 120.3826)),
        // 河北
        CityInfo(name: "石家庄", coordinate: CLLocationCoordinate2D(latitude: 38.0428, longitude: 114.5149)),
        CityInfo(name: "唐山", coordinate: CLLocationCoordinate2D(latitude: 39.6305, longitude: 118.1800)),
        // 辽宁
        CityInfo(name: "沈阳", coordinate: CLLocationCoordinate2D(latitude: 41.8057, longitude: 123.4315)),
        CityInfo(name: "大连", coordinate: CLLocationCoordinate2D(latitude: 38.9140, longitude: 121.6147)),
        // 黑龙江
        CityInfo(name: "哈尔滨", coordinate: CLLocationCoordinate2D(latitude: 45.8038, longitude: 126.5349)),
        // 吉林
        CityInfo(name: "长春", coordinate: CLLocationCoordinate2D(latitude: 43.8171, longitude: 125.3235)),
        // 安徽
        CityInfo(name: "合肥", coordinate: CLLocationCoordinate2D(latitude: 31.8206, longitude: 117.2272)),
        // 江西
        CityInfo(name: "南昌", coordinate: CLLocationCoordinate2D(latitude: 28.6820, longitude: 115.8579)),
        // 河南
        CityInfo(name: "郑州", coordinate: CLLocationCoordinate2D(latitude: 34.7466, longitude: 113.6253)),
        // 山西
        CityInfo(name: "太原", coordinate: CLLocationCoordinate2D(latitude: 37.8706, longitude: 112.5489)),
        // 内蒙古
        CityInfo(name: "呼和浩特", coordinate: CLLocationCoordinate2D(latitude: 40.8415, longitude: 111.7519)),
        // 广西
        CityInfo(name: "南宁", coordinate: CLLocationCoordinate2D(latitude: 22.8170, longitude: 108.3665)),
        CityInfo(name: "桂林", coordinate: CLLocationCoordinate2D(latitude: 25.2736, longitude: 110.2907)),
        // 贵州
        CityInfo(name: "贵阳", coordinate: CLLocationCoordinate2D(latitude: 26.6470, longitude: 106.6302)),
        // 云南
        CityInfo(name: "昆明", coordinate: CLLocationCoordinate2D(latitude: 25.0461, longitude: 102.7096)),
        // 甘肃
        CityInfo(name: "兰州", coordinate: CLLocationCoordinate2D(latitude: 36.0611, longitude: 103.8343)),
        // 新疆
        CityInfo(name: "乌鲁木齐", coordinate: CLLocationCoordinate2D(latitude: 43.8256, longitude: 87.6168)),
        // 西藏
        CityInfo(name: "拉萨", coordinate: CLLocationCoordinate2D(latitude: 29.6500, longitude: 91.1000)),
        // 海南
        CityInfo(name: "海口", coordinate: CLLocationCoordinate2D(latitude: 20.0440, longitude: 110.1999)),
        CityInfo(name: "三亚", coordinate: CLLocationCoordinate2D(latitude: 18.2524, longitude: 109.5119)),
        // 宁夏
        CityInfo(name: "银川", coordinate: CLLocationCoordinate2D(latitude: 38.4872, longitude: 106.2309)),
        // 青海
        CityInfo(name: "西宁", coordinate: CLLocationCoordinate2D(latitude: 36.6171, longitude: 101.7782)),
        // 香港/澳门
        CityInfo(name: "香港", coordinate: CLLocationCoordinate2D(latitude: 22.3193, longitude: 114.1694)),
        CityInfo(name: "澳门", coordinate: CLLocationCoordinate2D(latitude: 22.1987, longitude: 113.5439)),

        // 东亚
        CityInfo(name: "东京", coordinate: CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503)),
        CityInfo(name: "大阪", coordinate: CLLocationCoordinate2D(latitude: 34.6937, longitude: 135.5023)),
        CityInfo(name: "京都", coordinate: CLLocationCoordinate2D(latitude: 35.0116, longitude: 135.7681)),
        CityInfo(name: "横滨", coordinate: CLLocationCoordinate2D(latitude: 35.4437, longitude: 139.6380)),
        CityInfo(name: "首尔", coordinate: CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.9780)),
        CityInfo(name: "釜山", coordinate: CLLocationCoordinate2D(latitude: 35.1796, longitude: 129.0756)),
        CityInfo(name: "台北", coordinate: CLLocationCoordinate2D(latitude: 25.0330, longitude: 121.5654)),
        CityInfo(name: "高雄", coordinate: CLLocationCoordinate2D(latitude: 22.6273, longitude: 120.3014)),

        // 东南亚
        CityInfo(name: "新加坡", coordinate: CLLocationCoordinate2D(latitude: 1.3521, longitude: 103.8198)),
        CityInfo(name: "曼谷", coordinate: CLLocationCoordinate2D(latitude: 13.7563, longitude: 100.5018)),
        CityInfo(name: "吉隆坡", coordinate: CLLocationCoordinate2D(latitude: 3.1390, longitude: 101.6869)),
        CityInfo(name: "马尼拉", coordinate: CLLocationCoordinate2D(latitude: 14.5995, longitude: 120.9842)),
        CityInfo(name: "雅加达", coordinate: CLLocationCoordinate2D(latitude: -6.2088, longitude: 106.8456)),
        CityInfo(name: "河内", coordinate: CLLocationCoordinate2D(latitude: 21.0285, longitude: 105.8542)),
        CityInfo(name: "胡志明市", coordinate: CLLocationCoordinate2D(latitude: 10.8231, longitude: 106.6297)),

        // 南亚
        CityInfo(name: "孟买", coordinate: CLLocationCoordinate2D(latitude: 19.0760, longitude: 72.8777)),
        CityInfo(name: "德里", coordinate: CLLocationCoordinate2D(latitude: 28.7041, longitude: 77.1025)),
        CityInfo(name: "班加罗尔", coordinate: CLLocationCoordinate2D(latitude: 12.9716, longitude: 77.5946)),
        CityInfo(name: "加尔各答", coordinate: CLLocationCoordinate2D(latitude: 22.5726, longitude: 88.3639)),
        CityInfo(name: "卡拉奇", coordinate: CLLocationCoordinate2D(latitude: 24.8607, longitude: 67.0011)),

        // 中东
        CityInfo(name: "迪拜", coordinate: CLLocationCoordinate2D(latitude: 25.2048, longitude: 55.2708)),
        CityInfo(name: "利雅得", coordinate: CLLocationCoordinate2D(latitude: 24.7136, longitude: 46.6753)),
        CityInfo(name: "德黑兰", coordinate: CLLocationCoordinate2D(latitude: 35.6892, longitude: 51.3890)),
        CityInfo(name: "伊斯坦布尔", coordinate: CLLocationCoordinate2D(latitude: 41.0082, longitude: 28.9784)),

        // 欧洲
        CityInfo(name: "伦敦", coordinate: CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)),
        CityInfo(name: "巴黎", coordinate: CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522)),
        CityInfo(name: "柏林", coordinate: CLLocationCoordinate2D(latitude: 52.5200, longitude: 13.4050)),
        CityInfo(name: "莫斯科", coordinate: CLLocationCoordinate2D(latitude: 55.7558, longitude: 37.6173)),
        CityInfo(name: "罗马", coordinate: CLLocationCoordinate2D(latitude: 41.9028, longitude: 12.4964)),
        CityInfo(name: "马德里", coordinate: CLLocationCoordinate2D(latitude: 40.4168, longitude: -3.7038)),
        CityInfo(name: "阿姆斯特丹", coordinate: CLLocationCoordinate2D(latitude: 52.3676, longitude: 4.9041)),
        CityInfo(name: "维也纳", coordinate: CLLocationCoordinate2D(latitude: 48.2082, longitude: 16.3738)),
        CityInfo(name: "苏黎世", coordinate: CLLocationCoordinate2D(latitude: 47.3769, longitude: 8.5417)),
        CityInfo(name: "布鲁塞尔", coordinate: CLLocationCoordinate2D(latitude: 50.8503, longitude: 4.3517)),

        // 北美
        CityInfo(name: "纽约", coordinate: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)),
        CityInfo(name: "洛杉矶", coordinate: CLLocationCoordinate2D(latitude: 34.0522, longitude: -118.2437)),
        CityInfo(name: "芝加哥", coordinate: CLLocationCoordinate2D(latitude: 41.8781, longitude: -87.6298)),
        CityInfo(name: "多伦多", coordinate: CLLocationCoordinate2D(latitude: 43.6532, longitude: -79.3832)),
        CityInfo(name: "温哥华", coordinate: CLLocationCoordinate2D(latitude: 49.2827, longitude: -123.1207)),
        CityInfo(name: "旧金山", coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)),
        CityInfo(name: "西雅图", coordinate: CLLocationCoordinate2D(latitude: 47.6062, longitude: -122.3321)),
        CityInfo(name: "墨西哥城", coordinate: CLLocationCoordinate2D(latitude: 19.4326, longitude: -99.1332)),

        // 南美
        CityInfo(name: "圣保罗", coordinate: CLLocationCoordinate2D(latitude: -23.5505, longitude: -46.6333)),
        CityInfo(name: "布宜诺斯艾利斯", coordinate: CLLocationCoordinate2D(latitude: -34.6037, longitude: -58.3816)),
        CityInfo(name: "波哥大", coordinate: CLLocationCoordinate2D(latitude: 4.7110, longitude: -74.0721)),
        CityInfo(name: "圣地亚哥", coordinate: CLLocationCoordinate2D(latitude: -33.4489, longitude: -70.6693)),

        // 非洲
        CityInfo(name: "开罗", coordinate: CLLocationCoordinate2D(latitude: 30.0444, longitude: 31.2357)),
        CityInfo(name: "拉各斯", coordinate: CLLocationCoordinate2D(latitude: 6.5244, longitude: 3.3792)),
        CityInfo(name: "内罗毕", coordinate: CLLocationCoordinate2D(latitude: -1.2921, longitude: 36.8219)),
        CityInfo(name: "约翰内斯堡", coordinate: CLLocationCoordinate2D(latitude: -26.2041, longitude: 28.0473)),

        // 大洋洲
        CityInfo(name: "悉尼", coordinate: CLLocationCoordinate2D(latitude: -33.8688, longitude: 151.2093)),
        CityInfo(name: "墨尔本", coordinate: CLLocationCoordinate2D(latitude: -37.8136, longitude: 144.9631)),
        CityInfo(name: "奥克兰", coordinate: CLLocationCoordinate2D(latitude: -36.8509, longitude: 174.7645)),
        CityInfo(name: "布里斯班", coordinate: CLLocationCoordinate2D(latitude: -27.4698, longitude: 153.0251)),

        // MARK: - 河北（补充）
        CityInfo(name: "沧州",   coordinate: CLLocationCoordinate2D(latitude: 38.3043, longitude: 116.8388)),
        CityInfo(name: "保定",   coordinate: CLLocationCoordinate2D(latitude: 38.8671, longitude: 115.4647)),
        CityInfo(name: "邯郸",   coordinate: CLLocationCoordinate2D(latitude: 36.6252, longitude: 114.5390)),
        CityInfo(name: "秦皇岛", coordinate: CLLocationCoordinate2D(latitude: 39.9354, longitude: 119.5998)),
        CityInfo(name: "张家口", coordinate: CLLocationCoordinate2D(latitude: 40.7686, longitude: 114.8860)),
        CityInfo(name: "承德",   coordinate: CLLocationCoordinate2D(latitude: 40.9515, longitude: 117.9630)),
        CityInfo(name: "廊坊",   coordinate: CLLocationCoordinate2D(latitude: 39.5380, longitude: 116.6836)),
        CityInfo(name: "衡水",   coordinate: CLLocationCoordinate2D(latitude: 37.7390, longitude: 115.6703)),
        CityInfo(name: "邢台",   coordinate: CLLocationCoordinate2D(latitude: 37.0682, longitude: 114.5048)),

        // MARK: - 广东（补充）
        CityInfo(name: "中山",   coordinate: CLLocationCoordinate2D(latitude: 22.5176, longitude: 113.3927)),
        CityInfo(name: "惠州",   coordinate: CLLocationCoordinate2D(latitude: 23.1115, longitude: 114.4152)),
        CityInfo(name: "江门",   coordinate: CLLocationCoordinate2D(latitude: 22.5789, longitude: 113.0815)),
        CityInfo(name: "湛江",   coordinate: CLLocationCoordinate2D(latitude: 21.2707, longitude: 110.3594)),
        CityInfo(name: "茂名",   coordinate: CLLocationCoordinate2D(latitude: 21.6631, longitude: 110.9253)),
        CityInfo(name: "肇庆",   coordinate: CLLocationCoordinate2D(latitude: 23.0470, longitude: 112.4652)),
        CityInfo(name: "清远",   coordinate: CLLocationCoordinate2D(latitude: 23.6820, longitude: 113.0560)),
        CityInfo(name: "韶关",   coordinate: CLLocationCoordinate2D(latitude: 24.8105, longitude: 113.5975)),
        CityInfo(name: "河源",   coordinate: CLLocationCoordinate2D(latitude: 23.7435, longitude: 114.6977)),
        CityInfo(name: "阳江",   coordinate: CLLocationCoordinate2D(latitude: 21.8576, longitude: 111.9824)),
        CityInfo(name: "云浮",   coordinate: CLLocationCoordinate2D(latitude: 22.9280, longitude: 112.0447)),

        // MARK: - 江苏（补充）
        CityInfo(name: "徐州",   coordinate: CLLocationCoordinate2D(latitude: 34.2043, longitude: 117.1859)),
        CityInfo(name: "常州",   coordinate: CLLocationCoordinate2D(latitude: 31.7724, longitude: 119.9740)),
        CityInfo(name: "盐城",   coordinate: CLLocationCoordinate2D(latitude: 33.3479, longitude: 120.1637)),
        CityInfo(name: "扬州",   coordinate: CLLocationCoordinate2D(latitude: 32.3936, longitude: 119.4127)),
        CityInfo(name: "泰州",   coordinate: CLLocationCoordinate2D(latitude: 32.4554, longitude: 119.9154)),
        CityInfo(name: "镇江",   coordinate: CLLocationCoordinate2D(latitude: 32.1878, longitude: 119.4551)),
        CityInfo(name: "淮安",   coordinate: CLLocationCoordinate2D(latitude: 33.5596, longitude: 119.0210)),
        CityInfo(name: "连云港", coordinate: CLLocationCoordinate2D(latitude: 34.5966, longitude: 119.2216)),
        CityInfo(name: "宿迁",   coordinate: CLLocationCoordinate2D(latitude: 33.9633, longitude: 118.2754)),

        // MARK: - 浙江（补充）
        CityInfo(name: "嘉兴",   coordinate: CLLocationCoordinate2D(latitude: 30.7522, longitude: 120.7505)),
        CityInfo(name: "湖州",   coordinate: CLLocationCoordinate2D(latitude: 30.8700, longitude: 120.0939)),
        CityInfo(name: "绍兴",   coordinate: CLLocationCoordinate2D(latitude: 30.0300, longitude: 120.5800)),
        CityInfo(name: "金华",   coordinate: CLLocationCoordinate2D(latitude: 29.0785, longitude: 119.6472)),
        CityInfo(name: "衢州",   coordinate: CLLocationCoordinate2D(latitude: 28.9359, longitude: 118.8748)),
        CityInfo(name: "舟山",   coordinate: CLLocationCoordinate2D(latitude: 30.0164, longitude: 122.1069)),
        CityInfo(name: "台州",   coordinate: CLLocationCoordinate2D(latitude: 28.6561, longitude: 121.4216)),
        CityInfo(name: "丽水",   coordinate: CLLocationCoordinate2D(latitude: 28.4677, longitude: 119.9228)),

        // MARK: - 四川（补充）
        CityInfo(name: "德阳",   coordinate: CLLocationCoordinate2D(latitude: 31.1271, longitude: 104.3970)),
        CityInfo(name: "南充",   coordinate: CLLocationCoordinate2D(latitude: 30.7952, longitude: 106.0802)),
        CityInfo(name: "宜宾",   coordinate: CLLocationCoordinate2D(latitude: 28.7521, longitude: 104.6422)),
        CityInfo(name: "自贡",   coordinate: CLLocationCoordinate2D(latitude: 29.3392, longitude: 104.7782)),
        CityInfo(name: "乐山",   coordinate: CLLocationCoordinate2D(latitude: 29.5523, longitude: 103.7663)),
        CityInfo(name: "泸州",   coordinate: CLLocationCoordinate2D(latitude: 28.8918, longitude: 105.4418)),
        CityInfo(name: "达州",   coordinate: CLLocationCoordinate2D(latitude: 31.2097, longitude: 107.4677)),
        CityInfo(name: "内江",   coordinate: CLLocationCoordinate2D(latitude: 29.5802, longitude: 105.0580)),
        CityInfo(name: "遂宁",   coordinate: CLLocationCoordinate2D(latitude: 30.5332, longitude: 105.5926)),
        CityInfo(name: "攀枝花", coordinate: CLLocationCoordinate2D(latitude: 26.5825, longitude: 101.7184)),

        // MARK: - 湖北（补充）
        CityInfo(name: "宜昌",   coordinate: CLLocationCoordinate2D(latitude: 30.6917, longitude: 111.2865)),
        CityInfo(name: "襄阳",   coordinate: CLLocationCoordinate2D(latitude: 32.0094, longitude: 112.1224)),
        CityInfo(name: "荆州",   coordinate: CLLocationCoordinate2D(latitude: 30.3340, longitude: 112.2390)),
        CityInfo(name: "十堰",   coordinate: CLLocationCoordinate2D(latitude: 32.6291, longitude: 110.7985)),
        CityInfo(name: "黄冈",   coordinate: CLLocationCoordinate2D(latitude: 30.4535, longitude: 114.8716)),
        CityInfo(name: "孝感",   coordinate: CLLocationCoordinate2D(latitude: 30.9267, longitude: 113.9167)),
        CityInfo(name: "荆门",   coordinate: CLLocationCoordinate2D(latitude: 31.0354, longitude: 112.1995)),

        // MARK: - 湖南（补充）
        CityInfo(name: "株洲",   coordinate: CLLocationCoordinate2D(latitude: 27.8273, longitude: 113.1339)),
        CityInfo(name: "湘潭",   coordinate: CLLocationCoordinate2D(latitude: 27.8299, longitude: 112.9444)),
        CityInfo(name: "衡阳",   coordinate: CLLocationCoordinate2D(latitude: 26.8934, longitude: 112.5716)),
        CityInfo(name: "岳阳",   coordinate: CLLocationCoordinate2D(latitude: 29.3573, longitude: 113.1292)),
        CityInfo(name: "常德",   coordinate: CLLocationCoordinate2D(latitude: 29.0315, longitude: 111.6985)),
        CityInfo(name: "郴州",   coordinate: CLLocationCoordinate2D(latitude: 25.7706, longitude: 113.0143)),
        CityInfo(name: "邵阳",   coordinate: CLLocationCoordinate2D(latitude: 27.2418, longitude: 111.4677)),
        CityInfo(name: "益阳",   coordinate: CLLocationCoordinate2D(latitude: 28.5540, longitude: 112.3551)),

        // MARK: - 山东（补充）
        CityInfo(name: "烟台",   coordinate: CLLocationCoordinate2D(latitude: 37.5366, longitude: 121.3912)),
        CityInfo(name: "潍坊",   coordinate: CLLocationCoordinate2D(latitude: 36.7063, longitude: 119.1618)),
        CityInfo(name: "淄博",   coordinate: CLLocationCoordinate2D(latitude: 36.8131, longitude: 118.0548)),
        CityInfo(name: "临沂",   coordinate: CLLocationCoordinate2D(latitude: 35.0500, longitude: 118.3500)),
        CityInfo(name: "济宁",   coordinate: CLLocationCoordinate2D(latitude: 35.4146, longitude: 116.5876)),
        CityInfo(name: "泰安",   coordinate: CLLocationCoordinate2D(latitude: 36.1876, longitude: 117.0796)),
        CityInfo(name: "威海",   coordinate: CLLocationCoordinate2D(latitude: 37.5132, longitude: 122.1174)),
        CityInfo(name: "德州",   coordinate: CLLocationCoordinate2D(latitude: 37.4360, longitude: 116.3594)),
        CityInfo(name: "聊城",   coordinate: CLLocationCoordinate2D(latitude: 36.4565, longitude: 115.9850)),
        CityInfo(name: "滨州",   coordinate: CLLocationCoordinate2D(latitude: 37.3806, longitude: 117.9706)),
        CityInfo(name: "菏泽",   coordinate: CLLocationCoordinate2D(latitude: 35.2339, longitude: 115.4806)),
        CityInfo(name: "枣庄",   coordinate: CLLocationCoordinate2D(latitude: 34.8107, longitude: 117.3229)),
        CityInfo(name: "东营",   coordinate: CLLocationCoordinate2D(latitude: 37.4346, longitude: 118.6752)),
        CityInfo(name: "日照",   coordinate: CLLocationCoordinate2D(latitude: 35.4164, longitude: 119.5269)),

        // MARK: - 河南（补充）
        CityInfo(name: "洛阳",   coordinate: CLLocationCoordinate2D(latitude: 34.6182, longitude: 112.4536)),
        CityInfo(name: "开封",   coordinate: CLLocationCoordinate2D(latitude: 34.7973, longitude: 114.3071)),
        CityInfo(name: "南阳",   coordinate: CLLocationCoordinate2D(latitude: 32.9907, longitude: 112.5283)),
        CityInfo(name: "许昌",   coordinate: CLLocationCoordinate2D(latitude: 34.0357, longitude: 113.8523)),
        CityInfo(name: "周口",   coordinate: CLLocationCoordinate2D(latitude: 33.6274, longitude: 114.6497)),
        CityInfo(name: "新乡",   coordinate: CLLocationCoordinate2D(latitude: 35.3031, longitude: 113.9228)),
        CityInfo(name: "商丘",   coordinate: CLLocationCoordinate2D(latitude: 34.4140, longitude: 115.6501)),
        CityInfo(name: "信阳",   coordinate: CLLocationCoordinate2D(latitude: 32.1459, longitude: 114.0751)),
        CityInfo(name: "平顶山", coordinate: CLLocationCoordinate2D(latitude: 33.7365, longitude: 113.2972)),
        CityInfo(name: "安阳",   coordinate: CLLocationCoordinate2D(latitude: 36.1055, longitude: 114.3922)),
        CityInfo(name: "焦作",   coordinate: CLLocationCoordinate2D(latitude: 35.2154, longitude: 113.2419)),

        // MARK: - 辽宁（补充）
        CityInfo(name: "鞍山",   coordinate: CLLocationCoordinate2D(latitude: 41.1068, longitude: 122.9949)),
        CityInfo(name: "锦州",   coordinate: CLLocationCoordinate2D(latitude: 41.0953, longitude: 121.1268)),
        CityInfo(name: "抚顺",   coordinate: CLLocationCoordinate2D(latitude: 41.8798, longitude: 123.9577)),
        CityInfo(name: "营口",   coordinate: CLLocationCoordinate2D(latitude: 40.6676, longitude: 122.2348)),
        CityInfo(name: "本溪",   coordinate: CLLocationCoordinate2D(latitude: 41.2984, longitude: 123.7659)),
        CityInfo(name: "丹东",   coordinate: CLLocationCoordinate2D(latitude: 40.1290, longitude: 124.3531)),

        // MARK: - 黑龙江（补充）
        CityInfo(name: "齐齐哈尔", coordinate: CLLocationCoordinate2D(latitude: 47.3536, longitude: 123.9180)),
        CityInfo(name: "大庆",   coordinate: CLLocationCoordinate2D(latitude: 46.5892, longitude: 125.1032)),
        CityInfo(name: "牡丹江", coordinate: CLLocationCoordinate2D(latitude: 44.5521, longitude: 129.6324)),
        CityInfo(name: "佳木斯", coordinate: CLLocationCoordinate2D(latitude: 46.7997, longitude: 130.3176)),

        // MARK: - 安徽（补充）
        CityInfo(name: "芜湖",   coordinate: CLLocationCoordinate2D(latitude: 31.3521, longitude: 118.4328)),
        CityInfo(name: "蚌埠",   coordinate: CLLocationCoordinate2D(latitude: 32.9165, longitude: 117.3534)),
        CityInfo(name: "淮南",   coordinate: CLLocationCoordinate2D(latitude: 32.6258, longitude: 117.0163)),
        CityInfo(name: "安庆",   coordinate: CLLocationCoordinate2D(latitude: 30.5437, longitude: 117.0437)),
        CityInfo(name: "阜阳",   coordinate: CLLocationCoordinate2D(latitude: 32.8900, longitude: 115.8143)),
        CityInfo(name: "马鞍山", coordinate: CLLocationCoordinate2D(latitude: 31.6705, longitude: 118.5054)),

        // MARK: - 福建（补充）
        CityInfo(name: "泉州",   coordinate: CLLocationCoordinate2D(latitude: 24.8741, longitude: 118.6756)),
        CityInfo(name: "漳州",   coordinate: CLLocationCoordinate2D(latitude: 24.5135, longitude: 117.6471)),
        CityInfo(name: "莆田",   coordinate: CLLocationCoordinate2D(latitude: 25.4545, longitude: 119.0069)),
        CityInfo(name: "龙岩",   coordinate: CLLocationCoordinate2D(latitude: 25.0884, longitude: 117.0174)),

        // MARK: - 江西（补充）
        CityInfo(name: "赣州",   coordinate: CLLocationCoordinate2D(latitude: 25.8312, longitude: 114.9333)),
        CityInfo(name: "九江",   coordinate: CLLocationCoordinate2D(latitude: 29.7052, longitude: 116.0016)),
        CityInfo(name: "宜春",   coordinate: CLLocationCoordinate2D(latitude: 27.8032, longitude: 114.3914)),
        CityInfo(name: "吉安",   coordinate: CLLocationCoordinate2D(latitude: 27.1088, longitude: 114.9934)),
        CityInfo(name: "上饶",   coordinate: CLLocationCoordinate2D(latitude: 28.4542, longitude: 117.9429)),

        // MARK: - 山西（补充）
        CityInfo(name: "大同",   coordinate: CLLocationCoordinate2D(latitude: 40.0762, longitude: 113.2996)),
        CityInfo(name: "长治",   coordinate: CLLocationCoordinate2D(latitude: 36.1951, longitude: 113.1160)),
        CityInfo(name: "运城",   coordinate: CLLocationCoordinate2D(latitude: 35.0228, longitude: 111.0066)),
        CityInfo(name: "临汾",   coordinate: CLLocationCoordinate2D(latitude: 36.0881, longitude: 111.5190)),

        // MARK: - 陕西（补充）
        CityInfo(name: "宝鸡",   coordinate: CLLocationCoordinate2D(latitude: 34.3613, longitude: 107.2368)),
        CityInfo(name: "咸阳",   coordinate: CLLocationCoordinate2D(latitude: 34.3291, longitude: 108.7094)),
        CityInfo(name: "榆林",   coordinate: CLLocationCoordinate2D(latitude: 38.2849, longitude: 109.7340)),
        CityInfo(name: "渭南",   coordinate: CLLocationCoordinate2D(latitude: 34.4996, longitude: 109.5091)),

        // MARK: - 广西（补充）
        CityInfo(name: "柳州",   coordinate: CLLocationCoordinate2D(latitude: 24.3263, longitude: 109.4152)),
        CityInfo(name: "玉林",   coordinate: CLLocationCoordinate2D(latitude: 22.6364, longitude: 110.1803)),
        CityInfo(name: "贵港",   coordinate: CLLocationCoordinate2D(latitude: 23.1118, longitude: 109.5988)),
        CityInfo(name: "梧州",   coordinate: CLLocationCoordinate2D(latitude: 23.4764, longitude: 111.2797)),

        // MARK: - 贵州（补充）
        CityInfo(name: "遵义",   coordinate: CLLocationCoordinate2D(latitude: 27.7255, longitude: 106.9275)),
        CityInfo(name: "六盘水", coordinate: CLLocationCoordinate2D(latitude: 26.5935, longitude: 104.8467)),
        CityInfo(name: "毕节",   coordinate: CLLocationCoordinate2D(latitude: 27.3014, longitude: 105.2855)),

        // MARK: - 云南（补充）
        CityInfo(name: "曲靖",   coordinate: CLLocationCoordinate2D(latitude: 25.4896, longitude: 103.7974)),
        CityInfo(name: "大理",   coordinate: CLLocationCoordinate2D(latitude: 25.6065, longitude: 100.2676)),
        CityInfo(name: "玉溪",   coordinate: CLLocationCoordinate2D(latitude: 24.3528, longitude: 102.5471)),
        CityInfo(name: "昭通",   coordinate: CLLocationCoordinate2D(latitude: 27.3382, longitude: 103.7166)),
        CityInfo(name: "保山",   coordinate: CLLocationCoordinate2D(latitude: 25.1120, longitude: 99.1648)),

        // MARK: - 新疆（补充）
        CityInfo(name: "喀什",   coordinate: CLLocationCoordinate2D(latitude: 39.4677, longitude: 75.9906)),
        CityInfo(name: "库尔勒", coordinate: CLLocationCoordinate2D(latitude: 41.7256, longitude: 86.1747)),

        // MARK: - 内蒙古（补充）
        CityInfo(name: "包头",   coordinate: CLLocationCoordinate2D(latitude: 40.6567, longitude: 109.8402)),
        CityInfo(name: "赤峰",   coordinate: CLLocationCoordinate2D(latitude: 42.2563, longitude: 118.8888)),
        CityInfo(name: "鄂尔多斯", coordinate: CLLocationCoordinate2D(latitude: 39.6086, longitude: 109.7815)),
    ]

    /// 根据出生地字符串匹配城市，返回带确定性抖动的近似坐标
    /// - Parameters:
    ///   - location: 出生地字符串，如 "北京市海淀区"
    ///   - userId: 用于生成确定性抖动的用户ID
    /// - Returns: 近似坐标（±0.2°），未匹配到城市时返回 nil
    static func approximate(for location: String, userId: String) -> CLLocationCoordinate2D? {
        guard let city = findCity(for: location) else { return nil }

        // 确定性抖动（±0.2°），基于 userId hash
        let hash = abs(userId.hashValue)
        let latJitter = Double((hash % 400) - 200) / 1000.0        // ±0.2°
        let lonJitter = Double(((hash >> 8) % 400) - 200) / 1000.0

        return CLLocationCoordinate2D(
            latitude: city.coordinate.latitude + latJitter,
            longitude: city.coordinate.longitude + lonJitter
        )
    }

    /// 根据出生地字符串返回最匹配的城市名（用于 city 字段）
    static func matchedCityName(for location: String) -> String? {
        return findCity(for: location)?.name
    }

    // MARK: - Private

    private static func findCity(for location: String) -> CityInfo? {
        let normalized = location
            .replacingOccurrences(of: "市", with: "")
            .replacingOccurrences(of: "省", with: "")
            .replacingOccurrences(of: "区", with: "")
            .replacingOccurrences(of: "县", with: "")
            .trimmingCharacters(in: .whitespaces)

        // P0: 精确匹配（最高优先）
        if let city = cities.first(where: { $0.name == normalized }) {
            return city
        }

        // P1: 前缀匹配（城市名 >= 2 字，防止单字误匹配）
        if let city = cities.first(where: {
            $0.name.count >= 2 &&
            (normalized.hasPrefix($0.name) || $0.name.hasPrefix(normalized))
        }) { return city }

        // P2: 包含匹配（双方均 >= 2 字）
        if let city = cities.first(where: {
            $0.name.count >= 2 && normalized.count >= 2 &&
            (normalized.contains($0.name) || $0.name.contains(normalized))
        }) { return city }

        return nil
    }
}
