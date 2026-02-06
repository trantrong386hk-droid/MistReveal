import Foundation

/// 中国省市经度数据，用于真太阳时修正
struct ChinaCityData {

    struct City {
        let name: String
        let longitude: Double
    }

    // MARK: - 省份有序列表

    static let provinces: [String] = [
        "北京市", "天津市", "上海市", "重庆市",
        "河北省", "山西省", "辽宁省", "吉林省", "黑龙江省",
        "江苏省", "浙江省", "安徽省", "福建省", "江西省",
        "山东省", "河南省", "湖北省", "湖南省",
        "广东省", "海南省",
        "四川省", "贵州省", "云南省",
        "陕西省", "甘肃省", "青海省",
        "台湾省",
        "内蒙古自治区", "广西壮族自治区", "西藏自治区",
        "宁夏回族自治区", "新疆维吾尔自治区",
        "香港特别行政区", "澳门特别行政区"
    ]

    // MARK: - 省份 → 城市列表（含经度）

    static let cities: [String: [City]] = [
        // 直辖市
        "北京市": [
            City(name: "北京市", longitude: 116.41)
        ],
        "天津市": [
            City(name: "天津市", longitude: 117.19)
        ],
        "上海市": [
            City(name: "上海市", longitude: 121.47)
        ],
        "重庆市": [
            City(name: "重庆市", longitude: 106.50)
        ],

        // 河北省
        "河北省": [
            City(name: "石家庄市", longitude: 114.51),
            City(name: "唐山市", longitude: 118.18),
            City(name: "秦皇岛市", longitude: 119.60),
            City(name: "邯郸市", longitude: 114.54),
            City(name: "保定市", longitude: 115.46),
            City(name: "张家口市", longitude: 114.88),
            City(name: "承德市", longitude: 117.96),
            City(name: "廊坊市", longitude: 116.68),
            City(name: "沧州市", longitude: 116.86),
            City(name: "衡水市", longitude: 115.67),
            City(name: "邢台市", longitude: 114.50)
        ],

        // 山西省
        "山西省": [
            City(name: "太原市", longitude: 112.55),
            City(name: "大同市", longitude: 113.30),
            City(name: "阳泉市", longitude: 113.58),
            City(name: "长治市", longitude: 113.12),
            City(name: "晋城市", longitude: 112.85),
            City(name: "朔州市", longitude: 112.43),
            City(name: "忻州市", longitude: 112.73),
            City(name: "吕梁市", longitude: 111.14),
            City(name: "晋中市", longitude: 112.75),
            City(name: "临汾市", longitude: 111.52),
            City(name: "运城市", longitude: 111.01)
        ],

        // 辽宁省
        "辽宁省": [
            City(name: "沈阳市", longitude: 123.43),
            City(name: "大连市", longitude: 121.61),
            City(name: "鞍山市", longitude: 122.99),
            City(name: "抚顺市", longitude: 123.96),
            City(name: "本溪市", longitude: 123.77),
            City(name: "丹东市", longitude: 124.35),
            City(name: "锦州市", longitude: 121.13),
            City(name: "营口市", longitude: 122.24),
            City(name: "阜新市", longitude: 121.67),
            City(name: "辽阳市", longitude: 123.17),
            City(name: "盘锦市", longitude: 122.07),
            City(name: "铁岭市", longitude: 123.84),
            City(name: "朝阳市", longitude: 120.45),
            City(name: "葫芦岛市", longitude: 120.84)
        ],

        // 吉林省
        "吉林省": [
            City(name: "长春市", longitude: 125.32),
            City(name: "吉林市", longitude: 126.55),
            City(name: "四平市", longitude: 124.35),
            City(name: "辽源市", longitude: 125.14),
            City(name: "通化市", longitude: 125.94),
            City(name: "白山市", longitude: 126.42),
            City(name: "松原市", longitude: 124.82),
            City(name: "白城市", longitude: 122.84),
            City(name: "延吉市", longitude: 129.51)
        ],

        // 黑龙江省
        "黑龙江省": [
            City(name: "哈尔滨市", longitude: 126.63),
            City(name: "齐齐哈尔市", longitude: 123.92),
            City(name: "牡丹江市", longitude: 129.63),
            City(name: "佳木斯市", longitude: 130.32),
            City(name: "大庆市", longitude: 125.10),
            City(name: "鸡西市", longitude: 130.97),
            City(name: "双鸭山市", longitude: 131.16),
            City(name: "伊春市", longitude: 128.90),
            City(name: "七台河市", longitude: 131.00),
            City(name: "鹤岗市", longitude: 130.28),
            City(name: "黑河市", longitude: 127.53),
            City(name: "绥化市", longitude: 126.97)
        ],

        // 江苏省
        "江苏省": [
            City(name: "南京市", longitude: 118.80),
            City(name: "苏州市", longitude: 120.62),
            City(name: "无锡市", longitude: 120.31),
            City(name: "常州市", longitude: 119.97),
            City(name: "南通市", longitude: 120.86),
            City(name: "徐州市", longitude: 117.18),
            City(name: "盐城市", longitude: 120.16),
            City(name: "扬州市", longitude: 119.41),
            City(name: "泰州市", longitude: 119.92),
            City(name: "镇江市", longitude: 119.45),
            City(name: "淮安市", longitude: 119.02),
            City(name: "连云港市", longitude: 119.22),
            City(name: "宿迁市", longitude: 118.28)
        ],

        // 浙江省
        "浙江省": [
            City(name: "杭州市", longitude: 120.15),
            City(name: "宁波市", longitude: 121.55),
            City(name: "温州市", longitude: 120.67),
            City(name: "嘉兴市", longitude: 120.76),
            City(name: "湖州市", longitude: 120.09),
            City(name: "绍兴市", longitude: 120.58),
            City(name: "金华市", longitude: 119.65),
            City(name: "衢州市", longitude: 118.87),
            City(name: "舟山市", longitude: 122.11),
            City(name: "台州市", longitude: 121.42),
            City(name: "丽水市", longitude: 119.92)
        ],

        // 安徽省
        "安徽省": [
            City(name: "合肥市", longitude: 117.28),
            City(name: "芜湖市", longitude: 118.38),
            City(name: "蚌埠市", longitude: 117.39),
            City(name: "淮南市", longitude: 117.02),
            City(name: "马鞍山市", longitude: 118.51),
            City(name: "安庆市", longitude: 117.05),
            City(name: "黄山市", longitude: 118.34),
            City(name: "阜阳市", longitude: 115.81),
            City(name: "宿州市", longitude: 116.96),
            City(name: "滁州市", longitude: 118.32),
            City(name: "六安市", longitude: 116.52),
            City(name: "亳州市", longitude: 115.78),
            City(name: "池州市", longitude: 117.49),
            City(name: "宣城市", longitude: 118.76)
        ],

        // 福建省
        "福建省": [
            City(name: "福州市", longitude: 119.30),
            City(name: "厦门市", longitude: 118.09),
            City(name: "泉州市", longitude: 118.68),
            City(name: "漳州市", longitude: 117.65),
            City(name: "莆田市", longitude: 119.01),
            City(name: "龙岩市", longitude: 117.02),
            City(name: "三明市", longitude: 117.64),
            City(name: "南平市", longitude: 118.18),
            City(name: "宁德市", longitude: 119.53)
        ],

        // 江西省
        "江西省": [
            City(name: "南昌市", longitude: 115.86),
            City(name: "景德镇市", longitude: 117.18),
            City(name: "萍乡市", longitude: 113.85),
            City(name: "九江市", longitude: 116.00),
            City(name: "新余市", longitude: 114.93),
            City(name: "鹰潭市", longitude: 117.07),
            City(name: "赣州市", longitude: 114.93),
            City(name: "吉安市", longitude: 114.99),
            City(name: "宜春市", longitude: 114.39),
            City(name: "抚州市", longitude: 116.36),
            City(name: "上饶市", longitude: 117.94)
        ],

        // 山东省
        "山东省": [
            City(name: "济南市", longitude: 117.00),
            City(name: "青岛市", longitude: 120.38),
            City(name: "烟台市", longitude: 121.45),
            City(name: "潍坊市", longitude: 119.16),
            City(name: "淄博市", longitude: 118.05),
            City(name: "临沂市", longitude: 118.35),
            City(name: "济宁市", longitude: 116.59),
            City(name: "泰安市", longitude: 117.09),
            City(name: "威海市", longitude: 122.12),
            City(name: "日照市", longitude: 119.53),
            City(name: "德州市", longitude: 116.36),
            City(name: "聊城市", longitude: 115.98),
            City(name: "滨州市", longitude: 117.97),
            City(name: "菏泽市", longitude: 115.48),
            City(name: "枣庄市", longitude: 117.32),
            City(name: "东营市", longitude: 118.67)
        ],

        // 河南省
        "河南省": [
            City(name: "郑州市", longitude: 113.65),
            City(name: "洛阳市", longitude: 112.45),
            City(name: "开封市", longitude: 114.35),
            City(name: "南阳市", longitude: 112.53),
            City(name: "许昌市", longitude: 113.85),
            City(name: "周口市", longitude: 114.70),
            City(name: "新乡市", longitude: 113.88),
            City(name: "商丘市", longitude: 115.65),
            City(name: "信阳市", longitude: 114.07),
            City(name: "平顶山市", longitude: 113.19),
            City(name: "驻马店市", longitude: 114.02),
            City(name: "安阳市", longitude: 114.39),
            City(name: "焦作市", longitude: 113.24),
            City(name: "濮阳市", longitude: 115.03),
            City(name: "鹤壁市", longitude: 114.30),
            City(name: "三门峡市", longitude: 111.20),
            City(name: "漯河市", longitude: 114.02)
        ],

        // 湖北省
        "湖北省": [
            City(name: "武汉市", longitude: 114.30),
            City(name: "宜昌市", longitude: 111.29),
            City(name: "襄阳市", longitude: 112.14),
            City(name: "荆州市", longitude: 112.24),
            City(name: "十堰市", longitude: 110.79),
            City(name: "黄冈市", longitude: 114.87),
            City(name: "孝感市", longitude: 113.92),
            City(name: "荆门市", longitude: 112.20),
            City(name: "咸宁市", longitude: 114.32),
            City(name: "黄石市", longitude: 115.04),
            City(name: "恩施市", longitude: 109.49),
            City(name: "随州市", longitude: 113.38),
            City(name: "鄂州市", longitude: 114.89)
        ],

        // 湖南省
        "湖南省": [
            City(name: "长沙市", longitude: 112.94),
            City(name: "株洲市", longitude: 113.13),
            City(name: "湘潭市", longitude: 112.94),
            City(name: "衡阳市", longitude: 112.57),
            City(name: "岳阳市", longitude: 113.13),
            City(name: "常德市", longitude: 111.70),
            City(name: "郴州市", longitude: 113.01),
            City(name: "邵阳市", longitude: 111.47),
            City(name: "益阳市", longitude: 112.36),
            City(name: "永州市", longitude: 111.61),
            City(name: "怀化市", longitude: 110.00),
            City(name: "娄底市", longitude: 112.00),
            City(name: "湘西市", longitude: 109.74),
            City(name: "张家界市", longitude: 110.48)
        ],

        // 广东省
        "广东省": [
            City(name: "广州市", longitude: 113.26),
            City(name: "深圳市", longitude: 114.06),
            City(name: "珠海市", longitude: 113.58),
            City(name: "佛山市", longitude: 113.12),
            City(name: "东莞市", longitude: 113.75),
            City(name: "中山市", longitude: 113.38),
            City(name: "惠州市", longitude: 114.42),
            City(name: "汕头市", longitude: 116.68),
            City(name: "江门市", longitude: 113.08),
            City(name: "湛江市", longitude: 110.36),
            City(name: "茂名市", longitude: 110.92),
            City(name: "肇庆市", longitude: 112.46),
            City(name: "梅州市", longitude: 116.12),
            City(name: "揭阳市", longitude: 116.37),
            City(name: "清远市", longitude: 113.06),
            City(name: "韶关市", longitude: 113.60),
            City(name: "潮州市", longitude: 116.62),
            City(name: "汕尾市", longitude: 115.37),
            City(name: "河源市", longitude: 114.70),
            City(name: "阳江市", longitude: 111.98),
            City(name: "云浮市", longitude: 112.04)
        ],

        // 海南省
        "海南省": [
            City(name: "海口市", longitude: 110.35),
            City(name: "三亚市", longitude: 109.51),
            City(name: "儋州市", longitude: 109.58),
            City(name: "琼海市", longitude: 110.47),
            City(name: "文昌市", longitude: 110.80)
        ],

        // 四川省
        "四川省": [
            City(name: "成都市", longitude: 104.07),
            City(name: "绵阳市", longitude: 104.73),
            City(name: "德阳市", longitude: 104.40),
            City(name: "南充市", longitude: 106.11),
            City(name: "宜宾市", longitude: 104.64),
            City(name: "自贡市", longitude: 104.77),
            City(name: "乐山市", longitude: 103.77),
            City(name: "泸州市", longitude: 105.44),
            City(name: "达州市", longitude: 107.50),
            City(name: "内江市", longitude: 105.06),
            City(name: "遂宁市", longitude: 105.59),
            City(name: "攀枝花市", longitude: 101.72),
            City(name: "眉山市", longitude: 103.85),
            City(name: "广安市", longitude: 106.63),
            City(name: "资阳市", longitude: 104.63),
            City(name: "雅安市", longitude: 103.00),
            City(name: "广元市", longitude: 105.84),
            City(name: "巴中市", longitude: 106.77),
            City(name: "西昌市", longitude: 102.26),
            City(name: "康定市", longitude: 101.96),
            City(name: "马尔康市", longitude: 102.22)
        ],

        // 贵州省
        "贵州省": [
            City(name: "贵阳市", longitude: 106.71),
            City(name: "遵义市", longitude: 106.93),
            City(name: "六盘水市", longitude: 104.83),
            City(name: "安顺市", longitude: 105.95),
            City(name: "毕节市", longitude: 105.29),
            City(name: "铜仁市", longitude: 109.19),
            City(name: "凯里市", longitude: 107.98),
            City(name: "都匀市", longitude: 107.52),
            City(name: "兴义市", longitude: 104.90)
        ],

        // 云南省
        "云南省": [
            City(name: "昆明市", longitude: 102.83),
            City(name: "曲靖市", longitude: 103.80),
            City(name: "玉溪市", longitude: 102.55),
            City(name: "大理市", longitude: 100.23),
            City(name: "昭通市", longitude: 103.72),
            City(name: "保山市", longitude: 99.16),
            City(name: "丽江市", longitude: 100.23),
            City(name: "普洱市", longitude: 101.04),
            City(name: "临沧市", longitude: 100.09),
            City(name: "红河市", longitude: 103.38),
            City(name: "文山市", longitude: 104.24),
            City(name: "西双版纳市", longitude: 100.80),
            City(name: "景洪市", longitude: 100.80),
            City(name: "德宏市", longitude: 98.58),
            City(name: "芒市", longitude: 98.58)
        ],

        // 陕西省
        "陕西省": [
            City(name: "西安市", longitude: 108.94),
            City(name: "咸阳市", longitude: 108.71),
            City(name: "宝鸡市", longitude: 107.15),
            City(name: "渭南市", longitude: 109.50),
            City(name: "汉中市", longitude: 107.03),
            City(name: "安康市", longitude: 109.03),
            City(name: "商洛市", longitude: 109.94),
            City(name: "榆林市", longitude: 109.73),
            City(name: "延安市", longitude: 109.49),
            City(name: "铜川市", longitude: 108.95)
        ],

        // 甘肃省
        "甘肃省": [
            City(name: "兰州市", longitude: 103.83),
            City(name: "天水市", longitude: 105.72),
            City(name: "白银市", longitude: 104.17),
            City(name: "庆阳市", longitude: 107.64),
            City(name: "平凉市", longitude: 106.66),
            City(name: "酒泉市", longitude: 98.51),
            City(name: "张掖市", longitude: 100.45),
            City(name: "武威市", longitude: 102.64),
            City(name: "定西市", longitude: 104.63),
            City(name: "陇南市", longitude: 104.92),
            City(name: "嘉峪关市", longitude: 98.29),
            City(name: "金昌市", longitude: 102.19)
        ],

        // 青海省
        "青海省": [
            City(name: "西宁市", longitude: 101.77),
            City(name: "海东市", longitude: 102.10),
            City(name: "格尔木市", longitude: 94.90),
            City(name: "德令哈市", longitude: 97.37),
            City(name: "玉树市", longitude: 97.01)
        ],

        // 台湾省
        "台湾省": [
            City(name: "台北市", longitude: 121.56),
            City(name: "高雄市", longitude: 120.31),
            City(name: "台中市", longitude: 120.68),
            City(name: "台南市", longitude: 120.20),
            City(name: "新竹市", longitude: 120.97),
            City(name: "基隆市", longitude: 121.74)
        ],

        // 内蒙古自治区
        "内蒙古自治区": [
            City(name: "呼和浩特市", longitude: 111.75),
            City(name: "包头市", longitude: 109.84),
            City(name: "鄂尔多斯市", longitude: 109.78),
            City(name: "赤峰市", longitude: 118.89),
            City(name: "通辽市", longitude: 122.26),
            City(name: "呼伦贝尔市", longitude: 119.76),
            City(name: "巴彦淖尔市", longitude: 107.39),
            City(name: "乌兰察布市", longitude: 113.11),
            City(name: "乌海市", longitude: 106.79),
            City(name: "满洲里市", longitude: 117.38)
        ],

        // 广西壮族自治区
        "广西壮族自治区": [
            City(name: "南宁市", longitude: 108.37),
            City(name: "柳州市", longitude: 109.41),
            City(name: "桂林市", longitude: 110.29),
            City(name: "梧州市", longitude: 111.28),
            City(name: "北海市", longitude: 109.12),
            City(name: "防城港市", longitude: 108.35),
            City(name: "钦州市", longitude: 108.62),
            City(name: "贵港市", longitude: 109.60),
            City(name: "玉林市", longitude: 110.15),
            City(name: "百色市", longitude: 106.62),
            City(name: "贺州市", longitude: 111.57),
            City(name: "河池市", longitude: 108.06),
            City(name: "来宾市", longitude: 109.23),
            City(name: "崇左市", longitude: 107.36)
        ],

        // 西藏自治区
        "西藏自治区": [
            City(name: "拉萨市", longitude: 91.17),
            City(name: "日喀则市", longitude: 88.88),
            City(name: "昌都市", longitude: 97.17),
            City(name: "林芝市", longitude: 94.36),
            City(name: "山南市", longitude: 91.77),
            City(name: "那曲市", longitude: 92.06)
        ],

        // 宁夏回族自治区
        "宁夏回族自治区": [
            City(name: "银川市", longitude: 106.23),
            City(name: "石嘴山市", longitude: 106.38),
            City(name: "吴忠市", longitude: 106.20),
            City(name: "固原市", longitude: 106.28),
            City(name: "中卫市", longitude: 105.20)
        ],

        // 新疆维吾尔自治区
        "新疆维吾尔自治区": [
            City(name: "乌鲁木齐市", longitude: 87.62),
            City(name: "克拉玛依市", longitude: 84.87),
            City(name: "吐鲁番市", longitude: 89.19),
            City(name: "哈密市", longitude: 93.51),
            City(name: "昌吉市", longitude: 87.31),
            City(name: "库尔勒市", longitude: 86.07),
            City(name: "阿克苏市", longitude: 80.26),
            City(name: "喀什市", longitude: 75.99),
            City(name: "和田市", longitude: 79.92),
            City(name: "伊宁市", longitude: 81.33),
            City(name: "塔城市", longitude: 82.99),
            City(name: "阿勒泰市", longitude: 88.14),
            City(name: "石河子市", longitude: 86.04),
            City(name: "阿拉尔市", longitude: 81.29)
        ],

        // 香港特别行政区
        "香港特别行政区": [
            City(name: "香港", longitude: 114.17)
        ],

        // 澳门特别行政区
        "澳门特别行政区": [
            City(name: "澳门", longitude: 113.54)
        ]
    ]

    // MARK: - 经度查询

    /// 根据城市名查经度（模糊匹配：支持 "成都"、"成都市"、"四川成都" 等）
    static func longitude(for cityName: String) -> Double? {
        guard !cityName.isEmpty else { return nil }

        // 去掉常见后缀进行匹配
        let normalized = cityName
            .replacingOccurrences(of: "市", with: "")
            .replacingOccurrences(of: "县", with: "")
            .replacingOccurrences(of: "区", with: "")

        for (_, cityList) in cities {
            for city in cityList {
                let cityNorm = city.name.replacingOccurrences(of: "市", with: "")
                // 精确匹配
                if cityNorm == normalized { return city.longitude }
                // 包含匹配（处理 "四川成都" → "成都"）
                if normalized.contains(cityNorm) || cityNorm.contains(normalized) {
                    return city.longitude
                }
            }
        }

        // 省份名直接匹配 → 返回省会经度
        for (province, cityList) in cities {
            let provNorm = province
                .replacingOccurrences(of: "省", with: "")
                .replacingOccurrences(of: "市", with: "")
                .replacingOccurrences(of: "自治区", with: "")
                .replacingOccurrences(of: "壮族", with: "")
                .replacingOccurrences(of: "回族", with: "")
                .replacingOccurrences(of: "维吾尔", with: "")
                .replacingOccurrences(of: "特别行政区", with: "")
            if normalized.contains(provNorm) || provNorm.contains(normalized) {
                return cityList.first?.longitude
            }
        }

        return nil
    }
}
