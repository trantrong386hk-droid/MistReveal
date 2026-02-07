import Foundation
import LunarSwift

/// 阿里云百炼大模型文本生成服务
class TextGenerationService {

    static let shared = TextGenerationService()

    private init() {}

    // MARK: - 数据模型

    /// 灵魂伴侣数据响应（兼容旧版）
    struct SoulmateData: Codable {
        /// 连山易卦象名称
        let hexagram: String
        /// 给用户的真实性格与外貌描述
        let analysis: String
        /// 给即梦使用的中文绘图提示词
        let imagePrompt: String
        /// 用户八字信息（用于五行互补计算）
        var baziInfo: BaZiInfo?

        enum CodingKeys: String, CodingKey {
            case hexagram
            case analysis
            case imagePrompt = "image_prompt"
            case baziInfo = "bazi_info"
        }
    }

    /// API 请求体
    private struct ChatRequest: Encodable {
        let model: String
        let messages: [Message]
        let responseFormat: ResponseFormat?

        enum CodingKeys: String, CodingKey {
            case model, messages
            case responseFormat = "response_format"
        }

        struct Message: Encodable {
            let role: String
            let content: String
        }

        struct ResponseFormat: Encodable {
            let type: String
        }
    }

    /// API 响应体
    private struct ChatResponse: Decodable {
        let choices: [Choice]

        struct Choice: Decodable {
            let message: Message
        }

        struct Message: Decodable {
            let content: String
        }
    }

    // MARK: - 系统提示词

    /// 灵魂分析系统提示词
    private let soulAnalysisSystemPrompt = """
    你是一位结合现代心理学与中国传统命理学的灵魂架构师。你的核心能力是：读取五行能量场和十神力量格局，将抽象的命理数据转化为有血有肉、有灵魂温度的人物描写。

    你说话的方式：睿智、慈悲、能感同身受灵魂的温度。你洞察本质但不冷漠，你精准但有人情味。你是懂得共情的命理师——用数据说话，用温度收尾。

    【核心规则】
    - 异性伴侣匹配：男性用户 → 女性伴侣（用"她"）；女性用户 → 男性伴侣（用"他"）
    - 用户的八字、日主、五行分布、喜用神等硬核数据已由系统精确计算并提供，你不要自行推算，直接采用
    - user_element 字段必须与系统提供的日主五行完全一致
    - 所有人物描写（personality_description、soulmate_analysis、image_prompt）必须以五行能量和十神人设为驱动核心，严禁写出"大众脸""路人感"的人物
    - image_prompt 生成的人物必须有"灵魂重量"——五行决定气场色调，十神决定骨相气质，夫妻星决定眼神神态

    【禁用词汇】
    星辰、宿命、银河、轮回、天命、前世、来生、缘定三生、冥冥之中、冥冥中、注定
    韩系、网红、偶像、奶油、娃娃脸、初恋脸、氧气感

    【调候允许词汇】（当命理需要"调候"平衡寒热时可使用）
    少年感、清秀、精致、唯美、仙气、甜美、白净、小清新

    ========== 灵魂解析框架 ==========

    【第一层：日主解码 → 灵魂内核】
    根据系统提供的日主天干，解读其灵魂底色：
    - 甲木：参天大树型人格。有野心有骨气，但有时候硬得像块木头，不懂转弯
    - 乙木：藤蔓型人格。柔软但有韧性，看着好说话，其实内心有自己的一套
    - 丙火：太阳型人格。走到哪里都是焦点，热情到让人觉得有点"过"
    - 丁火：烛光型人格。表面安静，内心戏丰富到能写连续剧
    - 戊土：大山型人格。稳得像块石头，但浪漫对你来说是个技术难题
    - 己土：田园型人格。包容力强到有点没原则，什么人都想照顾
    - 庚金：利刃型人格。做事果断不拖泥带水，但说话也跟刀子一样
    - 辛金：珠玉型人格。精致、敏感、有品味，但有时候矫情得很
    - 壬水：大海型人格。脑子转得快，想法多到自己都管不住
    - 癸水：细雨型人格。敏锐、共情力强，但容易被别人的情绪影响

    【第二层：五行能量场 → 性格明暗面】
    结合五行加权得分的旺衰，分析性格的明面和暗面（总分125分，均值25分）：
    - 某五行得分 > 35 为偏旺：该特质外显、过度，需要抑制
    - 某五行得分 < 1 为缺失：该特质缺失，渴望补足
    - 喜用神所代表的特质 = 此人最需要、最向往、最容易被吸引的能量

    这一层要写出"你以为你是XX，其实你是YY"的洞察感。

    【第三层：喜用神 → 灵魂伴侣密码】
    喜用神是此人命格中最需要补足的能量，也是其灵魂伴侣的核心特质来源：
    - 喜金：需要一个有边界感、做事有章法、冷静理性的人来收住你
    - 喜木：需要一个有生命力、正能量、能带你成长的人来唤醒你
    - 喜水：需要一个灵活变通、懂你不说出口的话、情商在线的人来融化你
    - 喜火：需要一个热情主动、能点燃你激情、给你方向感的人来照亮你
    - 喜土：需要一个踏实靠谱、稳定输出安全感、让你放心的人来托住你

    【第四层：伴侣五行设定（系统已确定，不可更改）】

    唯一规则（不可覆写）：
    伴侣五行 = 系统提供的喜用神

    系统已使用专业调候算法精确计算喜用神（考虑了月令、寒暖、身强身弱等因素），
    你不得自行推算喜用神或以任何理由选择其他五行作为伴侣五行。
    即使你认为其他五行更合理，也必须服从系统计算结果。

    soulmate_element 字段必须填系统提供的喜用神，填其他值 = 系统级错误。

    伴侣的外貌、气质必须严格匹配喜用神对应的元素特质：
    - 喜用神=木 → 伴侣必须是木命（自然健康白里透红、松绿色服饰、林间光影）
    - 喜用神=火 → 伴侣必须是火命（红润有光泽、暖色调服饰、温暖光线）
    - 喜用神=金 → 伴侣必须是金命（白皙透亮、银灰色服饰、金属光泽）
    - 喜用神=水 → 伴侣必须是水命（水润细腻、深蓝色服饰、流动光影）
    - 喜用神=土 → 伴侣必须是土命（小麦色、驼色服饰、大地色调）

    【第五层：夫妻星骨相约束】（系统已提供夫妻星类型，必须严格执行）
    注意：此层只约束骨骼结构和体态，不涉及颜色、光影、服饰色调（那些由五行调色盘决定）。

    当夫/妻星为七杀（偏官）时：
    → 骨骼结构偏有力：轮廓清晰立体、骨架挺拔有力、下颌线转折分明、身姿从容坚定
    → 不要写成骨架纤细柔弱，也不要过分夸张（不写"颧骨突出""眉峰锋利"等极端词）

    当夫/妻星为正官时：
    → 骨骼结构偏端正：五官端正比例协调、额头宽阔饱满、体格匀称挺拔有分量感

    当夫/妻星为正财时：
    → 骨骼结构偏柔和：面部骨骼线条圆润柔和、体态匀称健康敦实、骨架给人安定感

    当夫/妻星为偏财时：
    → 骨骼结构偏灵活：五官骨骼鲜明有辨识度、体态匀称灵活有张力

    当无夫妻星时：
    → 骨骼结构跟随主导十神的体态方向

    【第六层：性格互补映射】
    基于系统确定的喜用神，描写伴侣如何补足用户的性格缺口：
    - 喜用神代表用户最渴望的能量 → 伴侣天生自带这种能量
    - 用户在生活中的具体痛点 → 伴侣用什么方式化解
    - 要写出具体场景，不要只写抽象标签
    - 注意：不要自行分析"用户缺什么五行"，伴侣五行已由系统确定

    【第七层：十神性格底色 → 用户人格 + 伴侣画像气质】

    A. 用户性格（命局主导十神决定核心行为模式）：
    - 正官主导：自律、守规矩、在意社会评价，但容易活得太"正确"
    - 七杀主导：有魄力、敢冒险、不服输，但控制欲强、容易走极端
    - 正财主导：务实、稳重、会过日子，但容易算计、缺乏浪漫
    - 偏财主导：慷慨、社交能力强、爱尝鲜，但花钱大手大脚
    - 食神主导：享受生活、有才华、性格温和，但容易懒散、缺乏紧迫感
    - 伤官主导：聪明、表达欲强、追求完美，但嘴毒、容易得罪人
    - 正印主导：善良、爱学习、有同理心，但优柔寡断、过度依赖
    - 偏印主导：独立思考、有特殊才华，但孤僻、想法偏执
    请结合主导十神与日主五行，给出更立体的性格画像。

    B. 伴侣画像气质（主导十神 → 伴侣的表情、姿态、神态方向，必须体现在 image_prompt 中）：
    注意：此处只约束表情和姿态，不涉及服饰颜色和环境色调（那些由五行调色盘决定）。

    - 七杀主导 → 表情坚毅果断，眼神锐利有穿透力，眉宇间英气外露，姿态挺拔有力
    - 正官主导 → 表情从容端正，眼神沉稳清澈，眉宇间舒展有度，举止得体有分寸
    - 正财主导 → 表情安稳真诚，眼神踏实笃定，嘴角自然带着善意，体态放松可靠
    - 偏财主导 → 表情生动爽朗，眼神灵活明亮，笑容有感染力，姿态轻松不拘束
    - 食神主导 → 表情松弛自在，眼神柔和慵懒，嘴角天然上扬，体态舒展放松
    - 伤官主导 → 表情清冽不羁，眼神锐利而有光彩，神态桀骜，姿态有张力
    - 正印主导 → 表情温和从容，眼神清澈笃定，眉宇间舒展，举止优雅不疾不徐
    - 偏印主导 → 表情沉思内敛，眼神深远有洞察力，神态独立，体态清瘦有棱角

    ========== 输出要求 ==========

    【语气风格】
    1. 赛博玄学感：像是一个能读取你灵魂数据的AI，冷静地告诉你真相
    2. 场景化洞察：如"你的八字里金太重——所以你是那种吵完架第二天就当没事的人，但对方可能已经哭了一晚上"
    3. 标签要精准毒辣：如"嘴硬心软""社交NPC""情绪黑洞""慢热到让人想放弃"
    4. 推导逻辑锋利：你的日主是X → 你的五行Y偏旺 → 所以你在感情中会Z → 因此你需要一个能A的人
    5. 外貌描述要让人"看到"那个人的灵魂：不是写真式的精致，而是有能量感的骨相——写出骨骼结构、肌肉张力、眼神深度、皮肤的温度和光泽
    6. image_prompt 中不要写相机参数（如35mm、Fujifilm、film grain等），要写光影氛围和能量质感
    7. image_prompt 禁止心理描写：不要写"他是一个有故事的人""内心丰富"等抽象心理文案。所有描述必须是肉眼可见的视觉特征。
       ✗ 错误："他的眼神透露着温柔与智慧"
       ✓ 正确："眼神清澈而笃定，眉宇间舒展，嘴角微微上扬"
    8. image_prompt 中的服饰颜色、肤色、光影和环境必须严格跟随用户消息中提供的「五行调色盘」，不要自行发挥其他色调

    【画像生成规则 - image_prompt】

    画面意境必须融合用户的喜用神五行（可能不止一个），叠加出复合场景。不要只套用单一元素的模板。

    单元素意境词库：
    - 金：银白冷调环境光、金属光泽质感、清冽通透的空气感
    - 木：自然光影斑驳、绿意葱茏、木质纹理的温暖氛围
    - 水：流动柔光、深蓝色调、水雾氤氲、月光倒影
    - 火：黄金时刻暖光、橙红氛围光、烛火般的温暖光晕
    - 土：大地色暖光、沉稳厚实质感、琥珀色柔光

    多元素复合意境（当喜用神涉及多个五行时，必须融合而非堆砌）：
    - 木+火 → "阳光穿透树冠的温暖森林"或"被落日余晖染成金色的竹林小径"
    - 木+水 → "雨后青苔上的水珠折射着绿光"或"溪流旁的古木书斋"
    - 金+水 → "月光洒在雪原上的银蓝世界"或"清晨薄雾中的银色湖面"
    - 火+土 → "壁炉旁的暖褐色书房"或"夕阳下的红砖老巷"
    - 土+金 → "秋日旷野上的金色麦浪"或"暮色中的石砌古堡"
    - 水+火 → "雨中霓虹倒影的都市街头"或"温泉升腾的暖雾中透出的烛光"
    - 木+土 → "山间茶园的晨雾中透出的泥土芬芳"或"古朴院落里的老树浓荫"
    - 金+火 → "锻铁火花飞溅的暗红车间"或"落日映照下的玻璃幕墙"
    - 水+木 → "江南烟雨中的青石板巷与垂柳"或"雾气缭绕的竹海深处"
    - 土+水 → "雨后泥土气息弥漫的田野"或"河畔黄昏的芦苇荡"

    规则：
    1. 从系统提供的"五行偏旺"和"喜用神"中提取最核心的 1~2 个五行元素
    2. 如果只有 1 个核心五行，使用单元素意境词库
    3. 如果有 2 个核心五行，必须使用复合意境，创造一个融合两种元素气质的自然场景
    4. 意境要能"闻到味道、感受到温度"，不要只写颜色和光线

    【输出格式】
    必须且只能返回以下 JSON，不要有任何其他文字：

    {
      "hexagram": "根据八字纳音推出的卦象或命格名称",
      "user_element": "用户日主五行（必须与系统提供的一致）",
      "soulmate_element": "直接填写系统提供的喜用神，禁止填其他值",
      "personality_description": "基于日主天干+主导十神+五行旺衰+喜用神的深度灵魂解析，赛博玄学风格，要有洞察感和共鸣感，100-150字",
      "personality_traits": ["精准毒辣的标签1", "标签2", "标签3", "标签4"],
      "relationship_behaviors": ["感情中的具体场景化表现1", "场景2", "场景3"],
      "emotional_needs": ["基于喜用神推导的情感需求1", "需求2", "需求3"],
      "matching_deductions": [
        {"user_trait": "你的命格特质（引用八字数据）", "soulmate_trait": "伴侣对应特质", "explanation": "用通俗语言解释为什么这种伴侣特质能帮到用户（不要写五行生克术语）"}
      ],
      "soulmate_traits": ["基于伴侣五行+喜用神推出的特质1", "特质2", "特质3", "特质4"],
      "compatibility_score": 82到96之间的整数,
      "destiny_type": "缘分类型（要有赛博感，如'量子纠缠型'、'引力共振型'）",
      "soulmate_appearance": {
        "skin_tone": "严格使用上方「五行调色盘」中的肤色描述，15-25字",
        "face_shape": "脸型描述，10-20字",
        "eyes": "眼睛特征+神态描写，20-35字",
        "other_features": "鼻、唇、其他特征，有辨识度，20-30字",
        "hair": "发型发色，15-25字",
        "clothing": "严格使用上方「五行调色盘」中的服饰色调，15-25字"
      },
      "soulmate_analysis": "综合伴侣五行+外貌+性格+与用户的互补关系，写一段完整生动的描述。要让用户觉得'这个人我好像在哪里见过'，200-300字",
      "image_prompt": "中文绘图提示词，80-120字，只写视觉特征，不写心理描写。格式：一位[年龄]岁的东方[男性/女性]，半身肖像，微侧面自然回眸，[肤色质感——具体描述皮肤的颜色和光泽，如'肌肤红润通透，颧骨处微微泛着健康的粉色']，[脸型骨相——具体描述骨骼结构，如'颧骨线条分明，下颌线转折干净利落']，[眼神——必须写出神态动作，如'眼神清澈而笃定，眉宇间舒展'，不要写'他是一个有故事的人'，严禁描写瞳色/眼珠颜色（如绿色、蓝色、琥珀色），东亚人瞳色为自然深棕/黑褐色]，[五官细节]，[发型发色]，身穿[具体颜色+材质的服饰，颜色必须融入喜用神五行，如喜火→'暗红色羊绒衫']，[场景环境——融合喜用神的具体场景，如喜火→'背景有温暖的壁炉光影，琥珀色的暖光弥漫'，不要只写抽象意境]"
    }
    """

    /// 旧版系统提示词（保留兼容）
    private let systemPrompt = """
    你是一位深藏不露的连山易专家。你通过生辰八字推算艮卦山势，洞察命中注定的缘分。

    你的回复规范：

    【人设】
    说话直白、干练、带点看透世俗的冷静。拒绝任何虚假、诗意、玄幻的词汇。
    严禁使用这些词：星辰、宿命、银河、轮回、天命、前世、来生、缘定三生。

    【内容要求】
    必须描述一个真实存在的人。包括：
    1. 外貌细节（占40%）：发型、肤色、五官特征、身材、穿衣偏好
    2. 性格特点（占40%）：性格短板（如固执、慢热、话少等）、脾气、待人方式
    3. 职业状态（占10%）：可能的职业类型、工作状态
    4. 生活习惯（占10%）：作息规律、兴趣爱好、日常习惯

    描述必须具体、接地气，避免笼统和套话。总字数控制在 200-300 字。

    【输出格式】
    为了方便 App 解析，请务必只返回以下 JSON 格式，不要有任何开场白或结尾文字：

    {
      "hexagram": "连山易卦象名称（如：艮为山、山天大畜、山地剥等）",
      "analysis": "这里写给用户的、接地气的性格与缘分描述文字（200-300字）",
      "image_prompt": "这里写一段专门给 AI 生图模型（如即梦/Flux）使用的中文描述词（100-150字）。必须强调：纪实摄影风格、真实人物、自然光影。描述五官、发型、气质、穿着等外在特征。"
    }
    """

    // MARK: - 禁用词汇清单生成

    /// 根据喜用神生成禁用词汇清单（与喜用神绑定）
    /// 木/火喜用神时额外禁止"冰冷"词汇，强调生命力和温度
    private func generateForbiddenWords(xiYongShen: String) -> String {
        switch xiYongShen {
        case "木":
            return """
            ❌ 禁用金系词汇：白皙透亮、银灰色、金属光泽、目光如刃、冷峻、骨相突出、轮廓分明、下颌线清晰、眼神清冷
            ❌ 禁用水系词汇：水润细腻、深蓝色、流动光影、灵动飘逸、眼波如水
            ❌ 禁用冰冷词汇：沉重、枯燥、压抑、冰冷、阴郁、灰暗、萧瑟、凋零、僵硬、死寂
            ✅ 必须使用：自然健康、肤色均匀有光泽、松绿色、林间光影、温润、有生命力、舒展、光影斑驳、清新、蓬勃
            """
        case "火":
            return """
            ❌ 禁用金系词汇：白皙透亮、银灰色、金属光泽、目光如刃、冷峻、骨相突出
            ❌ 禁用水系词汇：水润细腻、深蓝色、灵动飘逸
            ❌ 禁用冰冷词汇：沉重、枯燥、压抑、冰冷、阴郁、灰暗、萧瑟、凝滞、死气沉沉
            ✅ 必须使用：红润有光泽、暖色调、温暖光线、热情、目光如炬、明朗、活力、温度感、光芒
            """
        case "金":
            return """
            ❌ 禁用木系词汇：白里透红、松绿色、林间光影、温润
            ❌ 禁用火系词汇：红润、暖色调、目光如炬
            ✅ 必须使用：白皙透亮、银灰色、金属光泽、冷峻、轮廓分明
            ✅ 调候提示：若用户秋冬生人，背景需加入暖金色夕阳光或琥珀色余晖平衡寒气
            """
        case "水":
            return """
            ❌ 禁用火系词汇：红润、暖色调、温暖光线、目光如炬
            ❌ 禁用土系词汇：小麦色、蜜糖色、驼色
            ✅ 必须使用：水润细腻、深蓝色、流动光影、灵动、眼波如水
            ✅ 调候提示：若用户冬生人，背景需加入暖黄灯光或晨曦暖阳平衡寒气
            """
        case "土":
            return """
            ❌ 禁用金系词汇：白皙透亮、银灰色、金属光泽、冷峻
            ❌ 禁用水系词汇：深蓝色、流动光影、灵动飘逸
            ✅ 必须使用：小麦色、蜜糖色、驼色、大地色、沉稳厚重、温厚、敦实
            """
        default:
            return "✅ 根据伴侣五行选择对应的色调和质感词汇"
        }
    }

    // MARK: - 公开方法

    /// 根据完整生辰信息获取灵魂伴侣数据
    /// - Parameters:
    ///   - birthDate: 生辰日期字符串，如 "1990年5月15日"
    ///   - gender: 性灵属性（乾/坤）
    ///   - birthTime: 出生时辰（子时、丑时等）
    ///   - location: 出生地点
    /// - Returns: 灵魂伴侣数据
    func fetchSoulmateData(
        birthDate: String,
        gender: String,
        birthTime: String,
        location: String
    ) async throws -> SoulmateData {
        print("🔵 [TextGeneration] 开始生成灵魂伴侣数据")
        print("   - 生辰: \(birthDate)")
        print("   - 性别: \(gender)")
        print("   - 时辰: \(birthTime)")
        print("   - 地点: \(location)")

        // 从 SecretsManager 获取 API Key
        guard let apiKey = await SecretsManager.shared.getSecret("ALIYUN_BAILIAN_API_KEY") else {
            throw TextGenerationError.apiError(statusCode: 0, message: "无法获取 API 密钥")
        }

        let url = URL(string: "\(AppConfig.AliyunBailian.baseURL)/chat/completions")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // 先计算八字（获取 targetAge 用于 LLM 指令和后续生图，含真太阳时修正）
        let baziInfo = calculateBaZi(birthDate: birthDate, birthTime: birthTime, location: location, gender: gender == "乾" ? "男" : "女")

        var userMessage = """
        请根据以下信息推演这个人的灵魂伴侣：
        - 性灵属性：\(gender)
        - 降临日期：\(birthDate)
        - 出生时辰：\(birthTime)
        - 现世坐标：\(location)

        请推算艮卦山势，描述 ta 的灵魂伴侣的真实外貌、性格、职业和生活习惯。
        """

        // 如果有 targetAge，注入到 LLM 指令中
        if let tAge = baziInfo?.targetAge {
            userMessage += "\n\n【重要】image_prompt 中伴侣年龄必须写\(tAge)岁，不要使用其他年龄。"
        }

        let chatRequest = ChatRequest(
            model: AppConfig.AliyunBailian.model,
            messages: [
                ChatRequest.Message(role: "system", content: systemPrompt),
                ChatRequest.Message(role: "user", content: userMessage)
            ],
            responseFormat: ChatRequest.ResponseFormat(type: "json_object")
        )

        request.httpBody = try JSONEncoder().encode(chatRequest)

        print("🔵 [TextGeneration] 发送请求到阿里云百炼...")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TextGenerationError.invalidResponse
        }

        print("🔵 [TextGeneration] 收到响应，状态码: \(httpResponse.statusCode)")

        guard httpResponse.statusCode == 200 else {
            let errorText = String(data: data, encoding: .utf8) ?? "未知错误"
            print("❌ [TextGeneration] API 错误: \(errorText)")
            throw TextGenerationError.apiError(statusCode: httpResponse.statusCode, message: errorText)
        }

        let chatResponse = try JSONDecoder().decode(ChatResponse.self, from: data)

        guard let content = chatResponse.choices.first?.message.content else {
            throw TextGenerationError.emptyResponse
        }

        print("🔵 [TextGeneration] AI 返回内容: \(content.prefix(200))...")

        // 解析 JSON 内容
        guard let jsonData = content.data(using: .utf8) else {
            throw TextGenerationError.invalidJSON
        }

        var soulmateData = try JSONDecoder().decode(SoulmateData.self, from: jsonData)

        // 附加八字信息（已在上面提前计算）
        soulmateData.baziInfo = baziInfo
        if let bazi = baziInfo {
            print("✅ [TextGeneration] 八字计算成功: \(bazi.elementSummary), targetAge=\(bazi.targetAge ?? -1)")
        }

        print("✅ [TextGeneration] 解析成功")
        print("   - analysis: \(soulmateData.analysis.prefix(50))...")
        print("   - image_prompt: \(soulmateData.imagePrompt.prefix(50))...")

        return soulmateData
    }

    // MARK: - 灵魂分析（新版完整分析）

    /// 获取完整的灵魂分析结果
    /// - Parameters:
    ///   - birthDate: 生辰日期字符串，如 "1990年5月15日"
    ///   - gender: 性别（男/女）
    ///   - birthTime: 出生时辰（子时、丑时等）
    ///   - location: 出生地点
    /// - Returns: 完整的灵魂分析结果
    func fetchSoulAnalysis(
        birthDate: String,
        gender: String,
        birthTime: String,
        location: String
    ) async throws -> SoulAnalysisResult {
        print("🔵 [TextGeneration] 开始生成灵魂分析")
        print("   - 生辰: \(birthDate)")
        print("   - 性别: \(gender)")
        print("   - 时辰: \(birthTime)")
        print("   - 地点: \(location)")

        // 从 SecretsManager 获取 API Key
        guard let apiKey = await SecretsManager.shared.getSecret("ALIYUN_BAILIAN_API_KEY") else {
            throw TextGenerationError.apiError(statusCode: 0, message: "无法获取 API 密钥")
        }

        let url = URL(string: "\(AppConfig.AliyunBailian.baseURL)/chat/completions")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // 根据用户性别确定伴侣性别
        let soulmateGender = gender == "男" ? "女" : "男"
        let pronounHeShe = gender == "男" ? "她" : "他"

        // 使用 lunar-swift 计算精准八字（含真太阳时修正、十神、夫妻星）
        let baziInfo = calculateBaZi(birthDate: birthDate, birthTime: birthTime, location: location, gender: gender)

        // 构建用户消息
        var userMessage: String

        if let bazi = baziInfo {
            // 构建伴侣年龄指令（含视觉年龄补偿，抵消即梦模型加龄偏差）
            let ageInstruction: String
            let visualAgeText: String
            if let tAge = bazi.targetAge {
                let visualAge: Int
                if tAge <= 30 {
                    visualAge = tAge
                } else if tAge <= 35 {
                    visualAge = tAge - 2
                } else {
                    visualAge = tAge - 3
                }
                ageInstruction = "\n            4. image_prompt 中伴侣年龄必须写\(visualAge)岁，不要使用其他年龄"
                visualAgeText = """

                年龄外观约束：人物面部必须严格符合\(visualAge)岁的真实外观，皮肤紧致光滑，禁止添加法令纹、抬头纹、鱼尾纹等衰老特征。\
                必须展现无龄感的精神状态，内在生命力充沛，眼神明亮有神，散发着不受年龄束缚的年轻活力。
                """
                print("🔵 [TextGen] 年龄补偿: targetAge=\(tAge) → visualAge=\(visualAge)")
            } else {
                ageInstruction = ""
                visualAgeText = ""
            }

            // 判断是否为三柱推命模式
            let isThreePillar = (bazi.timePillar == "未知")

            // 提取时柱地支的五行（三柱模式下跳过）
            let timePillarZhi: String
            let timePillarElement: String
            if isThreePillar {
                timePillarZhi = ""
                timePillarElement = ""
            } else {
                timePillarZhi = String(bazi.timePillar.suffix(1))
                timePillarElement = zhiToElement[timePillarZhi] ?? "未知"
            }

            // 构建视觉注入数据（原 enhancePrompt 的核心逻辑，前置注入给 LLM）
            let imageGen = ImageGenerationService.shared
            let personaText = imageGen.shishenPersona(bazi.dominantGod)
            let spouseConstraintText = imageGen.spouseStarAppearance(bazi.spouseStarType)

            let palette = imageGen.elementToPalette(bazi.xiYongShen)
            let paletteLabel = bazi.xiYongShen

            let spouseBlock: String
            if let sct = spouseConstraintText, let sst = bazi.spouseStarType {
                spouseBlock = "\n            夫妻星骨相约束（\(sst)）：\(sct)"
            } else {
                spouseBlock = ""
            }

            // 排盘数据区：三柱 vs 四柱
            let pillarDataBlock: String
            if isThreePillar {
                pillarDataBlock = """
                三柱：\(bazi.yearPillar) \(bazi.monthPillar) \(bazi.dayPillar)（出生时间未知，无时柱）
                日主：\(bazi.dayStem)（\(bazi.dayStemElement)命）
                年柱纳音：\(bazi.yearNaYin)
                日柱纳音：\(bazi.dayNaYin)
                """
            } else {
                pillarDataBlock = """
                四柱：\(bazi.yearPillar) \(bazi.monthPillar) \(bazi.dayPillar) \(bazi.timePillar)
                日主：\(bazi.dayStem)（\(bazi.dayStemElement)命）
                时柱地支五行：\(timePillarZhi)\(timePillarElement)
                年柱纳音：\(bazi.yearNaYin)
                日柱纳音：\(bazi.dayNaYin)
                """
            }

            // 强制规则第5条：三柱模式下聚焦日主月令，四柱模式下引用时柱
            let rule5: String
            if isThreePillar {
                rule5 = "5. 注意：用户出生时间未知，请勿引用时柱或推测出生时辰。所有性格分析聚焦于日主和月令，基于上方三柱数据"
            } else {
                rule5 = "5. 所有性格分析和五行描述必须严格基于上方四柱数据，尤其是时柱\"\(bazi.timePillar)\"（\(timePillarZhi)\(timePillarElement)），不要使用用户输入的原始时间"
            }

            userMessage = """
            我已经通过专业历法引擎完成了这位用户的精准八字排盘（已经过真太阳时经度修正）。以下是硬核数据，请直接采用，不要自行推算：

            ═══ 系统排盘数据（真太阳时修正后）═══
            \(pillarDataBlock)
            五行能量分布：\(bazi.elementSummary)
            五行缺失：\(bazi.missingElements.isEmpty ? "无" : bazi.missingElements.joined(separator: "、"))
            五行偏旺：\(bazi.strongElements.isEmpty ? "均衡" : bazi.strongElements.joined(separator: "、"))
            喜用神：\(bazi.xiYongShen)（\(bazi.xiYongReason)）
            命局主导十神：\(bazi.dominantGod)
            十神分布：\(bazi.tenGodSummary)
            \(bazi.spouseStarType != nil ? "\(gender == "女" ? "夫" : "妻")星：\(bazi.spouseStarType!) 出现于 \(bazi.spouseStarPillars.joined(separator: "、"))" : "夫妻星：无")
            ═══════════════════════════════════

            ═══ image_prompt 视觉注入数据（三轴分离）═══
            以下三组数据各管各的维度，写 image_prompt 时严格逐条引用：
            - 十神人设 → 只决定表情和姿态（不含颜色）
            - 夫妻星骨相 → 只决定骨骼和体态（不含颜色）
            - 五行调色盘 → 只决定颜色、光影、服饰色调、环境

            十神人设气质（\(bazi.dominantGod)）：\(personaText)\(spouseBlock)

            五行调色盘（\(paletteLabel)）：
            - 肤色质感：\(palette.skinTone)
            - 服饰色调：\(palette.clothing)
            - 光影氛围：\(palette.lighting)
            - 环境场景：\(palette.environment)

            image_prompt 末尾必须追加：电影级特写肖像，浅景深虚化，微米级皮肤纹理，无滤镜真实感，佳能人像色调\(visualAgeText)
            ═══════════════════════════════════

            用户基本信息：\(gender)性，\(birthDate)生，现居\(location)

            【强制规则】
            1. user_element 必须填"\(bazi.dayStemElement)"
            2. 伴侣必须是\(soulmateGender)性，全文用"\(pronounHeShe)"称呼
            3. 【不可覆写】soulmate_element 必须填"\(bazi.xiYongShen)"，禁止填其他五行
               - 你不得自行推算喜用神，系统已用调候算法精确计算
               - image_prompt 的颜色/光影/服饰/环境 必须严格使用上方「五行调色盘」中的具体文字
               - soulmateAppearance 的 skin_tone/clothing 必须与「五行调色盘」一致
               - 伴侣外貌特质来源：ONLY 调色盘，绝不可参考其他五行
            4. 【严格禁用词汇清单】当喜用神=\(bazi.xiYongShen)时，以下词汇 = 违反命理 = 严重错误：
            \({
                let forbidden = generateForbiddenWords(xiYongShen: bazi.xiYongShen)
                print("🔵 [TextGen] 生成禁用词汇清单 (喜用神=\(bazi.xiYongShen)):")
                print(forbidden)
                return forbidden
            }())
            \(rule5)
            6. 伴侣画像的气质必须匹配主导十神"\(bazi.dominantGod)"对应的人设方向（参见第七层B部分）
            7. \(bazi.spouseStarType != nil ? "夫妻星为\(bazi.spouseStarType!)，伴侣的骨相、眼神、体态必须严格遵守第五层约束和上方视觉注入的夫妻星骨相约束" : "无夫妻星，以主导十神气质为主导")
            8. 严禁使用"清秀、精致、韩系、网红、甜美、白净、小清新"等词描述伴侣，伴侣必须有"五行能量感"而非"偶像感"
            9. image_prompt 只写肉眼可见的视觉特征，禁止心理描写（如"有故事""内心丰富"）
            10. image_prompt 严格遵守三轴分离：颜色/光影 → 只跟随「五行调色盘」；表情/姿态 → 只跟随「十神人设」；骨骼/体态 → 只跟随「夫妻星骨相」。十神描写中绝不可出现颜色词或温度词
            11. image_prompt 中人物面部必须符合目标年龄的真实外观，皮肤紧致光滑，禁止使用"成熟""沧桑""阅历""岁月沉淀"等老化词汇描述面部外观\(ageInstruction)
            12. image_prompt 中严禁描写瞳色或眼珠颜色，五行调色盘只影响服饰/光影/环境，不影响眼睛颜色。东亚人瞳色统一为自然深棕或黑褐色

            请基于以上数据进行深度灵魂解析，伴侣五行已由系统确定，请严格执行。
            """
        } else {
            userMessage = """
            请根据以下信息分析这个人的性格特质，并推导出最适合的伴侣类型：

            用户信息：\(gender)性，\(birthDate) \(birthTime)生，现居\(location)

            伴侣必须是\(soulmateGender)性，全文用"\(pronounHeShe)"称呼。
            """
        }

        let chatRequest = ChatRequest(
            model: AppConfig.AliyunBailian.model,
            messages: [
                ChatRequest.Message(role: "system", content: soulAnalysisSystemPrompt),
                ChatRequest.Message(role: "user", content: userMessage)
            ],
            responseFormat: ChatRequest.ResponseFormat(type: "json_object")
        )

        request.httpBody = try JSONEncoder().encode(chatRequest)

        print("🔵 [TextGeneration] 发送灵魂分析请求到阿里云百炼...")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TextGenerationError.invalidResponse
        }

        print("🔵 [TextGeneration] 收到响应，状态码: \(httpResponse.statusCode)")

        guard httpResponse.statusCode == 200 else {
            let errorText = String(data: data, encoding: .utf8) ?? "未知错误"
            print("❌ [TextGeneration] API 错误: \(errorText)")
            throw TextGenerationError.apiError(statusCode: httpResponse.statusCode, message: errorText)
        }

        let chatResponse = try JSONDecoder().decode(ChatResponse.self, from: data)

        guard let content = chatResponse.choices.first?.message.content else {
            throw TextGenerationError.emptyResponse
        }

        print("🔵 [TextGeneration] AI 返回内容: \(content.prefix(300))...")

        // 解析 JSON 内容
        guard let jsonData = content.data(using: .utf8) else {
            throw TextGenerationError.invalidJSON
        }

        var soulAnalysis = try JSONDecoder().decode(SoulAnalysisResult.self, from: jsonData)

        // 附加本地计算的八字数据
        soulAnalysis.baziInfo = baziInfo

        // 强制校正：soulmate_element 必须 = xiYongShen（防止 LLM 覆写）
        if let bazi = baziInfo, soulAnalysis.soulmateElement != bazi.xiYongShen {
            print("⚠️ [TextGen] LLM 覆写伴侣五行: \"\(soulAnalysis.soulmateElement)\" → 强制校正为 \"\(bazi.xiYongShen)\"")
            soulAnalysis.soulmateElement = bazi.xiYongShen
        }

        print("✅ [TextGeneration] 灵魂分析解析成功")
        print("   - 日主五行: \(baziInfo?.dayStemDescription ?? "未计算")")
        print("   - 性格描述: \(soulAnalysis.personalityDescription.prefix(50))...")
        print("   - 性格特质: \(soulAnalysis.personalityTraits)")
        print("   - 契合度: \(soulAnalysis.compatibilityScore)%")

        return soulAnalysis
    }

    // MARK: - 真太阳时

    /// 真太阳时修正结果
    struct TrueSolarTimeResult {
        let hour: Int
        let minute: Int
        let dayOffset: Int        // -1=回退一天, 0=当天, +1=进一天
        let correctionMinutes: Int // 修正量（分钟）
    }

    /// 计算真太阳时
    /// 公式：真太阳时 = 北京时间 + (当地经度 - 120°) × 4 分钟/度
    func calculateTrueSolarTime(hour: Int, minute: Int, longitude: Double?) -> TrueSolarTimeResult {
        guard let lng = longitude else {
            return TrueSolarTimeResult(hour: hour, minute: minute, dayOffset: 0, correctionMinutes: 0)
        }

        let correctionMinutes = Int(round((lng - 120.0) * 4.0))
        var totalMinutes = hour * 60 + minute + correctionMinutes
        var dayOffset = 0

        if totalMinutes < 0 {
            dayOffset = -1
            totalMinutes += 24 * 60
        } else if totalMinutes >= 24 * 60 {
            dayOffset = 1
            totalMinutes -= 24 * 60
        }

        return TrueSolarTimeResult(
            hour: totalMinutes / 60,
            minute: totalMinutes % 60,
            dayOffset: dayOffset,
            correctionMinutes: correctionMinutes
        )
    }

    // MARK: - 八字推演（lunar-swift）

    /// 时辰名称映射到小时
    /// 注意：子时分早子时(0:00-1:00)和晚子时(23:00-24:00)
    /// 用户选择"子时"时，我们默认用 0 点（早子时）
    /// 如果用户选择"晚子时"或"夜子时"，用 23 点
    private let birthTimeToHour: [String: Int] = [
        "子时": 0, "早子时": 0, "晚子时": 23, "夜子时": 23,
        "丒时": 2, "丑时": 2, "寅时": 4, "卯时": 6,
        "辰时": 8, "巳时": 10, "午时": 12, "未时": 14,
        "申时": 16, "酉时": 18, "戌时": 20, "亥时": 22
    ]

    /// 天干对应五行
    private let ganToElement: [String: String] = [
        "甲": "木", "乙": "木", "丙": "火", "丁": "火",
        "戊": "土", "己": "土", "庚": "金", "辛": "金",
        "壬": "水", "癸": "水"
    ]

    /// 地支对应五行（本气，用于 LLM 提示词中标注时柱地支五行等）
    private let zhiToElement: [String: String] = [
        "子": "水", "丑": "土", "寅": "木", "卯": "木",
        "辰": "土", "巳": "火", "午": "火", "未": "土",
        "申": "金", "酉": "金", "戌": "土", "亥": "水"
    ]

    // MARK: - 地支藏干表

    /// 地支藏干：每个地支内藏 1~3 个天干，按比例分配得分
    /// 比例来源：本气 70%（或 100%），中气 20~30%，余气 10%
    private struct HiddenStem {
        let stem: String       // 天干名
        let proportion: Double // 占比 (0.0~1.0)
    }

    private let zhiHiddenStems: [String: [HiddenStem]] = [
        "子": [HiddenStem(stem: "癸", proportion: 1.0)],
        "丑": [HiddenStem(stem: "己", proportion: 0.7), HiddenStem(stem: "癸", proportion: 0.2), HiddenStem(stem: "辛", proportion: 0.1)],
        "寅": [HiddenStem(stem: "甲", proportion: 0.7), HiddenStem(stem: "丙", proportion: 0.2), HiddenStem(stem: "戊", proportion: 0.1)],
        "卯": [HiddenStem(stem: "乙", proportion: 1.0)],
        "辰": [HiddenStem(stem: "戊", proportion: 0.7), HiddenStem(stem: "癸", proportion: 0.2), HiddenStem(stem: "乙", proportion: 0.1)],
        "巳": [HiddenStem(stem: "丙", proportion: 0.7), HiddenStem(stem: "庚", proportion: 0.2), HiddenStem(stem: "戊", proportion: 0.1)],
        "午": [HiddenStem(stem: "丁", proportion: 0.7), HiddenStem(stem: "己", proportion: 0.3)],
        "未": [HiddenStem(stem: "己", proportion: 0.7), HiddenStem(stem: "丁", proportion: 0.2), HiddenStem(stem: "乙", proportion: 0.1)],
        "申": [HiddenStem(stem: "庚", proportion: 0.7), HiddenStem(stem: "壬", proportion: 0.2), HiddenStem(stem: "戊", proportion: 0.1)],
        "酉": [HiddenStem(stem: "辛", proportion: 1.0)],
        "戌": [HiddenStem(stem: "戊", proportion: 0.7), HiddenStem(stem: "辛", proportion: 0.2), HiddenStem(stem: "丁", proportion: 0.1)],
        "亥": [HiddenStem(stem: "壬", proportion: 0.7), HiddenStem(stem: "甲", proportion: 0.3)]
    ]

    // MARK: - 十神系统

    /// 天干阴阳：1=阳, 0=阴
    private let ganYinYang: [String: Int] = [
        "甲": 1, "乙": 0, "丙": 1, "丁": 0,
        "戊": 1, "己": 0, "庚": 1, "辛": 0,
        "壬": 1, "癸": 0
    ]

    /// 五行相生相克关系（实例属性，供十神判定和喜用神推断复用）
    private let wuXingGenerates: [String: String] = [
        "木": "火", "火": "土", "土": "金", "金": "水", "水": "木"
    ]
    private let wuXingGeneratedBy: [String: String] = [
        "木": "水", "火": "木", "土": "火", "金": "土", "水": "金"
    ]
    private let wuXingControls: [String: String] = [
        "木": "土", "火": "金", "土": "水", "金": "木", "水": "火"
    ]
    private let wuXingControlledBy: [String: String] = [
        "木": "金", "火": "水", "土": "木", "金": "火", "水": "土"
    ]

    /// 判定某天干相对于日主的十神
    /// - Parameters:
    ///   - dayStem: 日干（"甲"..."癸"）
    ///   - otherStem: 待判定的天干
    /// - Returns: 十神名称（比肩/劫财/食神/伤官/偏财/正财/七杀/正官/偏印/正印）
    private func tenGod(dayStem: String, otherStem: String) -> String {
        let dayElement = ganToElement[dayStem]!
        let otherElement = ganToElement[otherStem]!
        let samePolarity = ganYinYang[dayStem] == ganYinYang[otherStem]

        if dayElement == otherElement {
            return samePolarity ? "比肩" : "劫财"
        } else if wuXingGenerates[dayElement] == otherElement {
            return samePolarity ? "食神" : "伤官"
        } else if wuXingControls[dayElement] == otherElement {
            return samePolarity ? "偏财" : "正财"
        } else if wuXingControlledBy[dayElement] == otherElement {
            return samePolarity ? "七杀" : "正官"
        } else {
            return samePolarity ? "偏印" : "正印"
        }
    }

    /// 从生辰信息计算精准八字（含真太阳时修正、十神计算、夫妻星定位、伴侣目标年龄推算）
    /// - Parameters:
    ///   - birthDate: 出生日期，格式如 "1990年5月15日"
    ///   - birthTime: 出生时间，支持 "14:30"（HH:mm）或 "辰时"（时辰）格式
    ///   - location: 出生城市名，用于经度查表做真太阳时修正（默认空字符串 = 不修正）
    ///   - gender: 性别（"男"/"女"），用于判定夫星/妻星（默认空 = 按男命处理）
    func calculateBaZi(birthDate: String, birthTime: String, location: String = "", gender: String = "") -> BaZiInfo? {
        // 解析日期字符串，如 "1990年5月15日"
        guard let (year, month, day) = parseBirthDate(birthDate) else {
            print("❌ [BaZi] 无法解析日期: \(birthDate)")
            return nil
        }

        // === 第一步：解析 birthTime ===
        let birthTimeUnknown = (birthTime == "未知")
        var hour: Int
        var minute: Int = 0

        if birthTimeUnknown {
            // 三柱推命：跳过时辰，用午时占位仅供 LunarSwift 调用（不参与得分）
            hour = 12
            minute = 0
            print("🔮 [BaZi] 出生时间未知，使用三柱推命模式")
        } else if birthTime.contains(":") {
            // 新格式 "14:30"
            let parts = birthTime.split(separator: ":")
            hour = Int(parts[0]) ?? 12
            minute = parts.count > 1 ? (Int(parts[1]) ?? 0) : 0
            print("🔮 [BaZi] 精确时间输入: \(hour):\(String(format: "%02d", minute))")
        } else {
            // 旧格式 "辰时" 或 "辰时 (07:00-09:00)"
            let timeKey = birthTimeToHour[birthTime] != nil
                ? birthTime
                : String(birthTime.prefix(while: { !$0.isWhitespace && $0 != "(" && $0 != "（" }))
            hour = birthTimeToHour[timeKey] ?? 12
            if birthTimeToHour[birthTime] == nil {
                print("⚠️ [BaZi] birthTime \"\(birthTime)\" 无精确匹配，截取为 \"\(timeKey)\" → hour=\(hour)")
            }
        }

        // === 第二步：真太阳时修正 ===
        let longitude = ChinaCityData.longitude(for: location)
        let trueSolar = calculateTrueSolarTime(hour: hour, minute: minute, longitude: longitude)

        var correctedYear = year
        var correctedMonth = month
        var correctedDay = day

        if trueSolar.dayOffset != 0 {
            let calendar = Calendar(identifier: .gregorian)
            let components = DateComponents(year: year, month: month, day: day)
            if let date = calendar.date(from: components),
               let adjusted = calendar.date(byAdding: .day, value: trueSolar.dayOffset, to: date) {
                let c = calendar.dateComponents([.year, .month, .day], from: adjusted)
                correctedYear = c.year ?? year
                correctedMonth = c.month ?? month
                correctedDay = c.day ?? day
            }
        }

        print("🔮 [BaZi] 排盘: \(year)年\(month)月\(day)日 \(hour):\(String(format: "%02d", minute)) (北京时间)")
        if longitude != nil {
            print("🔮 [BaZi] 经度: \(longitude!)° → 真太阳时修正: \(trueSolar.correctionMinutes)分钟 → \(correctedYear)年\(correctedMonth)月\(correctedDay)日 \(trueSolar.hour):\(String(format: "%02d", trueSolar.minute))")
        } else if !location.isEmpty {
            print("⚠️ [BaZi] 未找到 \"\(location)\" 的经度，跳过真太阳时修正")
        }

        // === 第三步：调用 lunar-swift ===
        let solar = Solar.fromYmdHms(year: correctedYear, month: correctedMonth, day: correctedDay, hour: trueSolar.hour, minute: trueSolar.minute, second: 0)
        let lunar = solar.lunar
        let eightChar = lunar.eightChar

        // sect 设置：控制晚子时(23:xx)的日柱归属
        //
        // sect=1（传统派）：晚子时日柱算次日
        // sect=2（0点换日）：晚子时日柱仍算当日
        //
        // 关键：当真太阳时修正已将日期回退（dayOffset < 0）且修正后落入 23:xx 时，
        // dayOffset 已经把日期减了 1 天，如果再用 sect=1 会多推 1 天，两次修正互相抵消。
        // 此时必须用 sect=2，避免 double-counting。
        //
        // 例：成都 00:30 → 真太阳时 前一天 23:26
        //   dayOffset=-1 把日期从 20 号退到 19 号
        //   sect=1 会把 19 号 23:xx 的日柱推到 20 号（抵消了修正）
        //   sect=2 保持 19 号日柱（正确）
        let useSect2ForCorrectedLateSub = (trueSolar.dayOffset < 0 && trueSolar.hour >= 23)
        eightChar.sect = useSect2ForCorrectedLateSub ? 2 : 1

        if useSect2ForCorrectedLateSub {
            print("🔮 [BaZi] 真太阳时修正跨入晚子时，使用 sect=2 避免日柱 double-counting")
        }

        // 四柱（基于节气的精确计算）
        let yearPillar = eightChar.year    // 使用 yearInGanZhiExact，立春换年
        let monthPillar = eightChar.month  // 使用 monthInGanZhiExact，节气换月
        let dayPillar = eightChar.day      // sect=1 时，晚子时算次日
        let timePillar = birthTimeUnknown ? "未知" : eightChar.time

        // 日主（日干）
        let dayStem = eightChar.dayGan
        let dayStemElement = ganToElement[dayStem] ?? "未知"

        // === 五行加权得分系统 ===
        // 天干：每个 10 分
        // 地支：年支/日支/时支各 15 分，月支（月令）40 分
        // 地支得分按藏干比例分配（如辰 = 70% 戊土 + 20% 癸水 + 10% 乙木）
        var elementScores: [String: Double] = ["金": 0, "木": 0, "水": 0, "火": 0, "土": 0]

        // 天干：每个 10 分，直接归属对应五行
        let allGan = birthTimeUnknown
            ? [eightChar.yearGan, eightChar.monthGan, eightChar.dayGan]
            : [eightChar.yearGan, eightChar.monthGan, eightChar.dayGan, eightChar.timeGan]
        for gan in allGan {
            if let e = ganToElement[gan] {
                elementScores[e, default: 0] += 10.0
            }
        }

        // 地支：按藏干比例分配得分
        // 月支权重 40 分（月令司令，命理核心），其余各 15 分
        let zhiBranches: [(String, Double)] = birthTimeUnknown ? [
            (eightChar.yearZhi, 15.0),   // 年支
            (eightChar.monthZhi, 40.0),  // 月支（月令）
            (eightChar.dayZhi, 15.0)     // 日支
            // 时支：出生时间未知，不含时支
        ] : [
            (eightChar.yearZhi, 15.0),   // 年支
            (eightChar.monthZhi, 40.0),  // 月支（月令）
            (eightChar.dayZhi, 15.0),    // 日支
            (eightChar.timeZhi, 15.0)    // 时支
        ]

        for (zhi, baseScore) in zhiBranches {
            if let hiddenStems = zhiHiddenStems[zhi] {
                for hs in hiddenStems {
                    if let e = ganToElement[hs.stem] {
                        elementScores[e, default: 0] += baseScore * hs.proportion
                    }
                }
            }
        }

        let metalScore = elementScores["金"] ?? 0
        let woodScore = elementScores["木"] ?? 0
        let waterScore = elementScores["水"] ?? 0
        let fireScore = elementScores["火"] ?? 0
        let earthScore = elementScores["土"] ?? 0

        let summary = "金\(String(format: "%.1f", metalScore)) 木\(String(format: "%.1f", woodScore)) 水\(String(format: "%.1f", waterScore)) 火\(String(format: "%.1f", fireScore)) 土\(String(format: "%.1f", earthScore))"

        // 缺失五行（得分 < 1，即几乎无此五行能量），按得分升序排列确保确定性
        let missing = elementScores.filter { $0.value < 1.0 }.sorted { $0.value < $1.value }.map { $0.key }
        // 偏旺五行（得分 > 35，总分 125 的 28%，高于均值 25 一个档位），按得分降序排列确保确定性
        let strong = elementScores.filter { $0.value > 35.0 }.sorted { $0.value > $1.value }.map { $0.key }

        // 喜用神推断：基于加权得分判断身强身弱（含调候优先逻辑）
        let (xiYong, xiReason) = inferXiYongShen(
            dayStemElement: dayStemElement,
            elementScores: elementScores,
            dayStem: dayStem,
            monthPillar: monthPillar
        )

        // 纳音
        let yearNaYin = eightChar.yearNaYin
        let dayNaYin = eightChar.dayNaYin

        // === 第四步：十神计算 ===

        // 天干十神（日干是自己，跳过）
        let ganPillars: [(name: String, stem: String)] = birthTimeUnknown ? [
            ("年柱", eightChar.yearGan),
            ("月柱", eightChar.monthGan)
        ] : [
            ("年柱", eightChar.yearGan),
            ("月柱", eightChar.monthGan),
            ("时柱", eightChar.timeGan)
        ]
        var tenGodMap: [(pillar: String, position: String, stem: String, god: String)] = []

        for (pillarName, stem) in ganPillars {
            let god = tenGod(dayStem: dayStem, otherStem: stem)
            tenGodMap.append((pillar: pillarName, position: "天干", stem: stem, god: god))
        }

        // 地支藏干十神（含日支 = 配偶宫）
        let zhiPillarNames: [(name: String, zhi: String, score: Double)] = birthTimeUnknown ? [
            ("年柱", eightChar.yearZhi, 15.0),
            ("月柱", eightChar.monthZhi, 40.0),
            ("日柱", eightChar.dayZhi, 15.0)
        ] : [
            ("年柱", eightChar.yearZhi, 15.0),
            ("月柱", eightChar.monthZhi, 40.0),
            ("日柱", eightChar.dayZhi, 15.0),
            ("时柱", eightChar.timeZhi, 15.0)
        ]

        for (pillarName, zhi, _) in zhiPillarNames {
            if let hiddenStems = zhiHiddenStems[zhi] {
                let mainStem = hiddenStems[0].stem
                let god = tenGod(dayStem: dayStem, otherStem: mainStem)
                tenGodMap.append((pillar: pillarName, position: "地支(\(zhi))", stem: mainStem, god: god))
            }
        }

        // 十神加权得分（用于找 dominantGod）
        var tenGodScores: [String: Double] = [:]

        // 天干部分：每个 10 分
        for (_, stem) in ganPillars {
            let god = tenGod(dayStem: dayStem, otherStem: stem)
            tenGodScores[god, default: 0] += 10.0
        }

        // 地支部分：按藏干比例 × 柱位权重
        for (_, zhi, baseScore) in zhiPillarNames {
            if let hiddenStems = zhiHiddenStems[zhi] {
                for hs in hiddenStems {
                    let god = tenGod(dayStem: dayStem, otherStem: hs.stem)
                    tenGodScores[god, default: 0] += baseScore * hs.proportion
                }
            }
        }

        // dominantGod：排除比肩/劫财（自身同类），取最高分十神
        let nonSelfGods = tenGodScores.filter { $0.key != "比肩" && $0.key != "劫财" }
        let dominantGod = nonSelfGods.max(by: { $0.value < $1.value })?.key ?? "正印"

        // 十神分布摘要
        let tenGodSummary = tenGodMap.map { "\($0.pillar)\($0.position):\($0.god)" }.joined(separator: "、")

        print("🔮 [BaZi] 十神分布: \(tenGodSummary)")
        let tenGodScoreSummary = tenGodScores.sorted { $0.value > $1.value }.map { "\($0.key)\(String(format: "%.1f", $0.value))" }.joined(separator: " ")
        print("🔮 [BaZi] 十神得分: \(tenGodScoreSummary)")
        print("🔮 [BaZi] 命局主导十神: \(dominantGod)")

        // === 第五步：夫/妻星定位 ===
        let spouseStarNames: [String]
        if gender == "女" {
            spouseStarNames = ["正官", "七杀"]
        } else {
            spouseStarNames = ["正财", "偏财"]  // 男命或默认
        }

        var spouseStarPillars: [String] = []
        var spouseStarType: String? = nil

        for starName in spouseStarNames {
            for entry in tenGodMap where entry.god == starName {
                if !spouseStarPillars.contains(entry.pillar) {
                    spouseStarPillars.append(entry.pillar)
                }
                if spouseStarType == nil {
                    spouseStarType = starName
                }
            }
        }

        if let sst = spouseStarType {
            print("🔮 [BaZi] \(gender == "女" ? "夫" : "妻")星: \(sst), 出现于 \(spouseStarPillars.joined(separator: "、"))")
        } else {
            print("🔮 [BaZi] 命中无\(gender == "女" ? "夫" : "妻")星")
        }

        // === 第六步：伴侣目标年龄推算 ===
        print("🔵 [BaZi] 开始计算伴侣目标年龄, birthDate=\"\(birthDate)\"")
        let userAge = calculateAge(from: birthDate)
        let targetAge: Int?
        let agePref: String
        let ageOffset: Int

        if birthTimeUnknown {
            // 时辰未知，默认同龄
            if let age = userAge {
                targetAge = max(18, age)
            } else {
                targetAge = nil
            }
            agePref = "时辰未知(同龄默认)"
            ageOffset = 0
            print("🔵 [BaZi] 时辰未知，使用同龄默认: targetAge=\(targetAge ?? -1)")
        } else {
            let (_agePref, _ageOffset) = inferAgePreference(
                spouseStarPillars: spouseStarPillars,
                dayStemElement: dayStemElement,
                elementScores: elementScores
            )
            agePref = _agePref
            ageOffset = _ageOffset
            if let age = userAge {
                targetAge = max(18, age + ageOffset)
                print("🔵 [BaZi] 用户\(age)岁, \(agePref)(offset=\(ageOffset)) → targetAge=\(targetAge!)")
            } else {
                targetAge = nil
                print("❌ [BaZi] calculateAge 返回 nil, targetAge 将为 nil!")
            }
        }

        let baziInfo = BaZiInfo(
            yearPillar: yearPillar,
            monthPillar: monthPillar,
            dayPillar: dayPillar,
            timePillar: timePillar,
            dayStem: dayStem,
            dayStemElement: dayStemElement,
            dayStemDescription: "\(dayStem)\(dayStemElement)",
            metalScore: metalScore,
            woodScore: woodScore,
            waterScore: waterScore,
            fireScore: fireScore,
            earthScore: earthScore,
            elementSummary: summary,
            missingElements: missing,
            strongElements: strong,
            xiYongShen: xiYong,
            xiYongReason: xiReason,
            yearNaYin: yearNaYin,
            dayNaYin: dayNaYin,
            targetAge: targetAge,
            agePreference: agePref,
            dominantGod: dominantGod,
            tenGodSummary: tenGodSummary,
            spouseStarType: spouseStarType,
            spouseStarPillars: spouseStarPillars
        )

        print("✅ [BaZi] 排盘完成 (sect=\(useSect2ForCorrectedLateSub ? 2 : 1), 真太阳时修正=\(trueSolar.correctionMinutes)分钟)")
        print("   北京时间: \(year)年\(month)月\(day)日 \(hour):\(String(format: "%02d", minute))")
        print("   真太阳时: \(correctedYear)年\(correctedMonth)月\(correctedDay)日 \(trueSolar.hour):\(String(format: "%02d", trueSolar.minute)) (dayOffset=\(trueSolar.dayOffset))")
        print("   农历: \(lunar.description)")
        print("   \(birthTimeUnknown ? "三柱" : "四柱"): \(yearPillar) \(monthPillar) \(dayPillar) \(birthTimeUnknown ? "(时柱未知)" : timePillar)")
        print("   日主: \(dayStem)\(dayStemElement)  五行分布: \(summary)")
        print("   喜用神: \(xiYong) (\(xiReason))")
        print("   年纳音: \(yearNaYin)  日纳音: \(dayNaYin)")
        if let age = userAge, let tAge = targetAge {
            print("   用户年龄: \(age)岁  年龄偏好: \(agePref)(offset=\(ageOffset))  伴侣目标年龄: \(tAge)岁")
        }

        return baziInfo
    }

    /// 解析 "1990年5月15日" 格式的日期字符串
    private func parseBirthDate(_ dateString: String) -> (Int, Int, Int)? {
        let pattern = #"(\d{4})年(\d{1,2})月(\d{1,2})日"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: dateString, range: NSRange(dateString.startIndex..., in: dateString)),
              match.numberOfRanges == 4 else {
            return nil
        }

        let yearRange = Range(match.range(at: 1), in: dateString)!
        let monthRange = Range(match.range(at: 2), in: dateString)!
        let dayRange = Range(match.range(at: 3), in: dateString)!

        guard let year = Int(dateString[yearRange]),
              let month = Int(dateString[monthRange]),
              let day = Int(dateString[dayRange]) else {
            return nil
        }

        return (year, month, day)
    }

    // MARK: - 伴侣年龄推算

    /// 根据用户 birthDate 计算实际年龄（支持多种日期格式）
    private func calculateAge(from birthDate: String) -> Int? {
        // 优先使用 parseBirthDate（"1990年5月15日" 格式）
        if let (year, month, day) = parseBirthDate(birthDate) {
            let calendar = Calendar.current
            var birthComponents = DateComponents()
            birthComponents.year = year
            birthComponents.month = month
            birthComponents.day = day

            guard let birth = calendar.date(from: birthComponents) else {
                print("⚠️ [Age] DateComponents 无法生成日期: \(year)-\(month)-\(day)")
                return nil
            }
            let ageComponents = calendar.dateComponents([.year], from: birth, to: Date())
            print("🔵 [Age] 解析成功: \(birthDate) → 年龄 \(ageComponents.year ?? -1)岁")
            return ageComponents.year
        }

        // 兜底：尝试提取年份直接计算
        let yearPattern = #"(\d{4})"#
        if let regex = try? NSRegularExpression(pattern: yearPattern),
           let match = regex.firstMatch(in: birthDate, range: NSRange(birthDate.startIndex..., in: birthDate)),
           let range = Range(match.range(at: 1), in: birthDate),
           let year = Int(birthDate[range]) {
            let age = Calendar.current.component(.year, from: Date()) - year
            print("🔵 [Age] 兜底解析: 从 \"\(birthDate)\" 提取年份 \(year) → 年龄 \(age)岁")
            return age
        }

        print("❌ [Age] 无法从 \"\(birthDate)\" 解析年龄")
        return nil
    }

    /// 根据夫/妻星柱位推算伴侣目标年龄偏好
    ///
    /// 策略：夫/妻星出现在哪个柱位决定伴侣年龄方向
    /// - 年柱 → +3（早年遇配偶，略年长）
    /// - 月柱 → +1（青年遇配偶，微年长）
    /// - 日柱 → 0（配偶宫，同龄）
    /// - 时柱 → -3（晚年遇配偶，偏年轻）
    /// - 多柱取平均；无夫妻星则回退到身强身弱逻辑
    private func inferAgePreference(
        spouseStarPillars: [String],
        dayStemElement: String,
        elementScores: [String: Double]
    ) -> (agePreference: String, ageOffset: Int) {

        if spouseStarPillars.isEmpty {
            // 无夫/妻星 → 回退到身强身弱逻辑
            let selfScore = elementScores[dayStemElement] ?? 0
            let helperScore = elementScores[wuXingGeneratedBy[dayStemElement] ?? ""] ?? 0
            let selfStrength = selfScore + helperScore

            if selfStrength < 30 {
                return ("印(无夫妻星)", 3)
            } else if selfStrength > 75 {
                return ("食伤(无夫妻星)", -3)
            } else {
                return ("default(无夫妻星)", 0)
            }
        }

        let pillarOffsets: [String: Int] = [
            "年柱": 3,
            "月柱": 1,
            "日柱": 0,
            "时柱": -3
        ]

        var totalOffset = 0
        var count = 0
        var pillarNames: [String] = []

        for pillar in spouseStarPillars {
            if let offset = pillarOffsets[pillar] {
                totalOffset += offset
                count += 1
                pillarNames.append(pillar)
            }
        }

        let avgOffset = count > 0 ? totalOffset / count : 0
        let reason = pillarNames.joined(separator: "+")

        return ("\(reason)见夫妻星", avgOffset)
    }

    /// 喜用神推断（基于加权得分）
    ///
    /// 得分体系：天干 10 分 × 4 + 地支 15 分 × 3 + 月支 40 分 = 总计 125 分
    /// 地支得分按藏干比例分配（如辰 = 70% 土 + 20% 水 + 10% 木）
    ///
    /// 判断逻辑：
    /// - selfStrength = 日主同类得分 + 生我者（印星）得分
    /// - selfStrength < 50（低于均值）→ 身弱，喜印星（生我者）
    /// - selfStrength ≥ 50 → 身旺，喜食伤（我生者）泄秀
    ///
    /// 特殊调候优先规则：
    /// - 壬水日主 + 申月（秋金旺水寒）→ 优先取火（调候）或木（泄秀），避免金（加重寒冷）
    private func inferXiYongShen(dayStemElement: String, elementScores: [String: Double], dayStem: String, monthPillar: String) -> (String, String) {
        let selfScore = elementScores[dayStemElement] ?? 0
        let helperElement = wuXingGeneratedBy[dayStemElement] ?? ""
        let helperScore = elementScores[helperElement] ?? 0
        let selfStrength = selfScore + helperScore

        // 🔍 DEBUG: 打印关键参数
        print("🔍 [DEBUG] inferXiYongShen 参数:")
        print("   dayStem = \"\(dayStem)\"")
        print("   monthPillar = \"\(monthPillar)\"")
        print("   dayStemElement = \"\(dayStemElement)\"")
        print("   selfStrength = \(selfStrength)")
        print("   判断条件: dayStem == \"壬\" ? \(dayStem == "壬")")
        print("   判断条件: monthPillar.contains(\"申\") ? \(monthPillar.contains("申"))")
        print("   两者同时满足? \(dayStem == "壬" && monthPillar.contains("申"))")

        // 🔥 调候优先：壬水生于申月（秋金旺，水寒）
        if dayStem == "壬" && monthPillar.contains("申") {
            print("✅ [DEBUG] 触发调候优先逻辑")
            // 优先取火（温暖调候）或木（泄秀生发）
            let fireScore = elementScores["火"] ?? 0
            let woodScore = elementScores["木"] ?? 0

            if fireScore < 10 && woodScore >= 15 {
                // 火极弱，木相对足够 → 优先木（泄秀生发，避免寒冷）
                return ("木", "壬水生于申月，金水两旺而寒冷，火不足以调候，取木泄秀生发，带来温暖生机")
            } else if fireScore < 10 {
                // 火弱但木也不足 → 优先火（调候为先）
                return ("火", "壬水生于申月，金水两旺而寒冷，急需火来温暖调候，驱散秋水之寒")
            } else {
                // 火相对充足 → 取木泄秀
                return ("木", "壬水生于申月，秋金旺水寒，取木泄秀生发，化解金水的冷肃之气")
            }
        }

        // 常规身强身弱判定（总分 125，自身+印星的均值约 50）
        if selfStrength < 50 {
            let xiElement = wuXingGeneratedBy[dayStemElement] ?? dayStemElement
            print("❌ [DEBUG] 使用常规逻辑（身弱）: 喜用神 = \(xiElement)")
            return (xiElement, "日主\(dayStemElement)偏弱(力量\(String(format: "%.1f", selfStrength))/125)，需要\(xiElement)来生扶")
        } else {
            let xiElement = wuXingGenerates[dayStemElement] ?? "土"
            print("❌ [DEBUG] 使用常规逻辑（身旺）: 喜用神 = \(xiElement)")
            return (xiElement, "日主\(dayStemElement)偏旺(力量\(String(format: "%.1f", selfStrength))/125)，需要\(xiElement)来泄耗平衡")
        }
    }

    // MARK: - 错误类型

    enum TextGenerationError: LocalizedError {
        case invalidResponse
        case apiError(statusCode: Int, message: String)
        case emptyResponse
        case invalidJSON

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "无效的响应"
            case .apiError(let statusCode, let message):
                return "API 错误 (\(statusCode)): \(message)"
            case .emptyResponse:
                return "AI 返回内容为空"
            case .invalidJSON:
                return "无法解析 AI 返回的 JSON"
            }
        }
    }
}
