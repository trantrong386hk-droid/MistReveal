import Foundation
import LunarSwift
import Supabase

/// 阿里云百炼大模型文本生成服务
class TextGenerationService {

    static let shared = TextGenerationService()
    static let soulAnalysisPromptVersion = "v2.1"

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

    /// API 请求体（发送到 aliyun-proxy EF，含额外字段供 EF 存入 prompt_tokens）
    private struct ChatRequest: Encodable {
        let model: String
        let messages: [Message]
        let responseFormat: ResponseFormat?
        var targetAge: Int? = nil      // 供 aliyun-proxy 存入 prompt_tokens
        var xiYongShen: String = ""    // 供 aliyun-proxy 存入 prompt_tokens
        var soulmateGender: String = "" // 供 aliyun-proxy 选择性别适配发型/服饰

        enum CodingKeys: String, CodingKey {
            case model, messages
            case responseFormat = "response_format"
            case targetAge = "target_age"
            case xiYongShen = "xi_yong_shen"
            case soulmateGender = "soulmate_gender"
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

    /// 灵魂分析系统提示词（拆分成多段避免编译器 OOM）
    private var soulAnalysisSystemPrompt: String {
        let part1 = """
        你是一位结合现代心理学与中国传统命理学的灵魂架构师。你的任务是把系统提供的命理数据转化为有画面、有性格、有气质的人物描写。

        【硬性规则】
        - 异性伴侣匹配：男性用户 → 女性伴侣（用"她"）；女性用户 → 男性伴侣（用"他"）
        - 所有命理数据由系统提供，你不要自行推算
        - user_element 必须与系统提供的日主五行一致
        - soulmate_element 必须等于系统提供的喜用神，不可更改
        - 禁用词：星辰、宿命、银河、轮回、天命、前世、来生、缘定三生、冥冥之中、注定；韩系、网红、偶像、奶油、娃娃脸、初恋脸、氧气感
        """

        let part2 = """

        【伴侣画像原则】
        - 伴侣五行 = 喜用神，体现为"能量感受"，不要用元素字面颜色
        - 视觉重点：骨相结构、体态张力、眼神神态、皮肤质感
        - 服饰自由选择，追求真实生活感和多样性，每次生成应有不同的穿搭风格
        - 发色必须自然黑/深棕，不染发、不挑染
        - 五行能量只体现在气质、光影与环境，不体现在发色或瞳色
        - 光线尽量中性暖光，背景优先选择中性室内/城市质感场景，避免大量绿植

        【输出风格——极其重要】
        口语化、有温度、真实感——像一个特别懂你的朋友在说话，不是命理师在写分析报告。
        核心原则：把八字结论翻译成用户的生活体验和情绪感受，让读者产生"就是我"的强烈共鸣。
        - 用"你"直接对话，短句，节奏轻快，避免长难句
        - 写具体的行为、场景、情绪，不写抽象术语
        - 带一点"洞察感"——像朋友说了一句"你就是这样的人"，让人既意外又觉得准
        - 禁止：命局、日主、十神、五行生克等术语出现在用户可见的内容字段中
        """

        let part3 = """

        【各字段写法示例】
        personality_description: 用"你"直接对话，写具体行为或情绪，让读者产生"这说的就是我"的感觉。不写命理术语。100-150字。
        好的示例："你很少主动说'我需要你'，但你的行动会替你说出这句话。别人开口之前，你早就默默做好了。"
        坏的示例："日主壬水，印绶护身，情感上呈现出内敛保护型特质"

        relationship_behaviors: 用"你会…"或"你总是…"开头，写感情中具体场景，让人觉得被看透了。
        好的示例："在喜欢的人面前，你反而会变得有点安静，不像平时那么活跃"
        坏的示例："感情中内敛保守，不善主动表达"

        emotional_needs: 用内心独白语气，如"你需要一个…"或"你希望他能…"
        好的示例："你需要一个不用你解释，他就能懂你在想什么的人"

        matching_deductions explanation: 用生活化语言解释，有具体场景感，40-60字。
        好的示例："你容易想太多，脑子转个不停。你需要的是那种能把你从自己念头里拉出来的人——不是给你讲道理，而是陪你发呆"
        坏的示例："木能生火，补足用户命局中火气不足"

        【深度报告字段写法——让人觉得被一眼看穿】
        这四个字段是报告的灵魂。写法要比其他字段更深、更私密、更让人震撼。
        核心原则：每句话都要让用户感觉"这是在说我，不是在说一类人"。

        love_wound: 写用户在感情里反复出现的一个具体模式——不是缺点，是一个被命局刻进去的习惯。
        结构：先说模式（你总是…），再说代价（然后你会…），最后说根源（这不是你的错，是因为你内心深处…）。80-100字。
        好的示例："你总是在关系变好之前先退一步——不是不喜欢，是太怕再一次靠近之后又要离开。你明明很渴望被珍惜，却偏偏在那个人靠近的时候表现得像你不在乎。这是你保护自己的方式，但它也让真正想靠近你的人不知道该怎么办。"
        坏的示例："感情中容易受伤，需要注意保护自己"

        shadow_trait: 写用户不会对外展示、但自己心里清楚的那一面。不是缺点，是一种隐藏的真实。
        结构：先说外部印象（别人以为你…），再揭示内心（但你自己知道…），最后点出对比带来的张力（这两面同时存在于你身上）。60-80字。
        好的示例："别人以为你很平静，很好相处，什么都放得下。但你自己知道，你只是把那些在意的事压得很深，不让它们出来。你不是真的不在乎，你只是不想让人看到你在乎的样子——那让你觉得自己太脆弱了。"
        坏的示例："表面冷静，内心敏感，双重性格"

        compatibility_analysis: 三段式，每段2-3句。不要用标题，自然衔接。120-160字。
        第一段：你们会在哪件事上产生强烈的化学反应（具体场景，不是笼统说"互补"）
        第二段：你们之间可能产生摩擦的地方（写具体，不要说"需要磨合"）
        第三段：这段关系能给你带来什么——不是浪漫描述，是一种真实的成长
        好的示例："你习惯把情绪藏着，Ta 偏偏能在你不说话的时候准确猜到你在想什么——这会让你既有点慌又很安心。你们最容易起摩擦的地方是节奏不同：你需要时间想清楚再行动，Ta 可能已经等不住了。但也正是这段关系，会让你第一次真正相信，不用解释也能被理解——这件事你其实一直在等。"

        meeting_timing: 不要给具体年份，写"什么状态/阶段"下 Ta 会出现。有画面感，有命格依据，但不承诺时间。50-70字。
        好的示例："Ta 不会在你最努力寻找的时候出现。往往是你终于停下来，不再把'遇到谁'当成一件重要的事之后——在某个你没想到的场合，以一种你没预料到的方式，Ta 就这样出现了。"
        坏的示例："2026年下半年感情运势上升，适合寻找伴侣"

        message_to_soulmate: 一句话，像是用户写给还没出现的那个人的。高度个人化，基于命格定制，有点诗意但不矫情。15-25字。
        好的示例："如果你已经在某个地方了，我想让你知道，我正在慢慢变成值得你出现的人。"
        坏的示例："期待与你相遇，共度美好时光"
        """

        let part4 = """

        【输出格式】必须且只能返回以下JSON，不要有任何其他文字：
        {"hexagram":"根据八字纳音推出的卦象名称（2-5字，有仪式感）","user_element":"用户日主五行","soulmate_element":"直接填写系统提供的喜用神","personality_description":"用你直接对话，写具体行为或情绪体验，让读者产生这说的就是我的感觉。不写命理术语。100-150字","personality_traits":["简短有力的特质标签3字以内","标签2","标签3","标签4"],"relationship_behaviors":["感情中具体场景用你会或你总是开头","场景2","场景3"],"emotional_needs":["用内心独白语气写渴望如你需要一个","需求2","需求3"],"matching_deductions":[{"user_trait":"你的某个性格特点口语化","soulmate_trait":"ta对应的特质","explanation":"生活化语言解释为什么这样的人适合你40-60字"}],"soulmate_traits":["ta的外在特质标签3字以内","外在特质2","内在特质1","内在特质2","内在特质3","内在特质4"],"compatibility_score":82到96之间的整数,"destiny_type":"缘分类型2-6字有意境如灵魂共鸣互补之缘","share_quote":"一句专属命格金句15-25字，有被一眼看穿的惊喜感，格式：你是那种…的人 或 有一种人…那就是你","soulmate_appearance":{"skin_tone":"传递五行能量方向感受15-25字","face_shape":"脸型描述10-20字","eyes":"眼睛特征加神态描写20-35字","other_features":"鼻唇其他特征20-30字","hair":"发型发色女性发型多样化15-25字","clothing":"日常服饰追求真实感15-25字"},"soulmate_analysis":"口语化有温度描述伴侣，让用户觉得这个人我好像在哪里见过，200-300字，不写命理术语","image_prompt":"中文绘图提示词80-120字，只写视觉特征不写心理描写，格式：一位[年龄]岁的东方[男/女]，半身肖像，微侧面自然回眸，[肤色质感]，[脸型骨相]，[眼神神态动作，严禁描写瞳色]，[五官细节]，[发型发色]，身穿[日常服饰风格多样]，[室内或城市背景中性光线]","love_wound":"你在感情里反复出现的模式——先说模式再说代价再说根源，让用户觉得被一眼看穿。80-100字，用你直接对话，有震撼感","shadow_trait":"你不会对外展示但自己心里清楚的那一面——先说外部印象再揭示内心，60-80字，口语化，让人点头说就是这样","compatibility_analysis":"三段式120-160字：第一段你们的化学反应具体场景，第二段你们的摩擦点要具体，第三段这段关系给你的真实成长。不要用标题，自然衔接","meeting_timing":"什么状态或阶段下Ta会出现——不给具体年份，写有画面感的场景，50-70字，要让人觉得说的是自己的故事","message_to_soulmate":"一句写给还没出现的Ta的话，15-25字，高度个人化，有点诗意但不矫情，基于命格","character":{"name":"角色名2字，根据五行选择有意境的名字（木系如林晚/叶笙，水系如苏霁/沈澜，金系如顾凛/白砚，火系如谢烬/燃橙，土系如沈稳/陆岩），不要用常见大众名","age":25到30之间的整数,"occupation_desc":"在[成都/杭州/大理/苏州/厦门/重庆/西安/上海老弄堂]做[具体职业]的12-18字描述，职业参考：木-独立撰稿人/书店主理人/植物绘制师，水-心理咨询师/独立摄影师/诗集编辑，金-产品设计师/音乐制作人/珠宝设计师，火-舞台导演/旅行视频作者/咖啡馆主理人，土-手工陶艺者/餐厅主理人/烘焙品牌创始人","hobbies":["具体爱好1（和职业相关或日常生活细节）","爱好2","爱好3"],"love_style":"感情方式和态度，具体行为描述，30-45字","speaking_habit":"说话习惯和节奏，越具体越好，20-30字","intro_tagline":"有独特性的一句话，不超过15字，让人想认识这个人","intro_story":"有生活感的个人介绍，写城市/工作/日常片段，50-70字，口语化，有画面感"}}
        """

        return part1 + part2 + part3 + part4
    }

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
            ✅ 必须使用：自然健康、有生命力、清新、蓬勃、质朴、温润
            """
        case "火":
            return """
            ❌ 禁用金系词汇：白皙透亮、银灰色、金属光泽、目光如刃、冷峻、骨相突出
            ❌ 禁用水系词汇：水润细腻、深蓝色、灵动飘逸
            ❌ 禁用冰冷词汇：沉重、枯燥、压抑、冰冷、阴郁、灰暗、萧瑟、凝滞、死气沉沉
            ✅ 必须使用：温暖、有温度感、明朗、活力、光芒
            """
        case "金":
            return """
            ❌ 禁用木系词汇：白里透红、松绿色、林间光影、温润
            ❌ 禁用火系词汇：红润、暖色调、目光如炬
            ✅ 必须使用：冷峻、利落、轮廓分明、通透、干净
            ✅ 调候提示：若用户秋冬生人，背景需加入暖金色夕阳光或琥珀色余晖平衡寒气
            """
        case "水":
            return """
            ❌ 禁用火系词汇：红润、暖色调、温暖光线、目光如炬
            ❌ 禁用土系词汇：小麦色、蜜糖色、驼色
            ✅ 必须使用：水润细腻、灵动、流动、沉静、深邃
            ✅ 调候提示：若用户冬生人，背景需加入暖黄灯光或晨曦暖阳平衡寒气
            """
        case "土":
            return """
            ❌ 禁用金系词汇：白皙透亮、银灰色、金属光泽、冷峻
            ❌ 禁用水系词汇：深蓝色、流动光影、灵动飘逸
            ✅ 必须使用：沉稳、厚实、温厚、敦实、踏实、有分量
            """
        default:
            return "✅ 根据伴侣五行选择对应的色调和质感词汇"
        }
    }

    // MARK: - 五行能量方向

    /// 根据喜用神五行和伴侣性别，返回能量方向 + 光线环境描述（服饰不受五行约束）
    private func elementEnergyDescription(_ element: String, soulmateGender: String) -> String {
        switch element {
        case "木":
            return """
            用户命局缺生机，伴侣应传递「蓬勃生命力」的视觉感受。
            气质方向：清爽、通透、有活力、松弛自然。
            光线环境：中性暖光，背景以室内/城市质感场景为主，避免大量绿植。
            服饰：自由选择任何有质感的日常服饰，不受五行色调限制。注重面料质感和穿搭的真实生活感。
            """
        case "火":
            return """
            用户命局缺温暖，伴侣应传递「被温暖包裹」的视觉感受。
            气质方向：温暖、有温度、亲近、让人安心。
            光线环境：中性暖光，室内/城市质感场景为主，避免强色环境。
            服饰：自由选择任何有质感的日常服饰，不受五行色调限制。注重面料质感和穿搭的真实生活感。
            """
        case "金":
            return """
            用户命局缺秩序，伴侣应传递「干净利落」的视觉感受。
            气质方向：精致、干净、克制、有分寸感。
            光线环境：中性冷白光或中性暖光，极简室内/城市质感场景。
            服饰：自由选择任何有质感的日常服饰，不受五行色调限制。注重面料质感和穿搭的真实生活感。
            """
        case "水":
            return """
            用户命局缺柔韧，伴侣应传递「沉静疏解」的视觉感受。
            气质方向：沉静、从容、柔和、不张扬的高级感。
            光线环境：柔和低饱和光线，室内/城市质感场景为主，避免强色环境。
            服饰：自由选择任何有质感的日常服饰，不受五行色调限制。注重面料质感和穿搭的真实生活感。
            """
        case "土":
            return """
            用户命局缺安全感，伴侣应传递「踏实安定」的视觉感受。
            气质方向：沉稳、可靠、踏实、有安全感。
            光线环境：中性暖光，室内/城市质感场景为主，避免强色环境。
            服饰：自由选择任何有质感的日常服饰，不受五行色调限制。注重面料质感和穿搭的真实生活感。
            """
        default:
            return "根据伴侣五行选择对应的气质感受方向。"
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

        print("🔵 [TextGeneration] 发送请求到 aliyun-proxy Edge Function...")

        let session = try await supabase.auth.refreshSession()
        let chatResponse: ChatResponse = try await supabase.functions.invoke(
            "aliyun-proxy",
            options: FunctionInvokeOptions(
                method: .post,
                headers: ["Authorization": "Bearer \(session.accessToken)"],
                body: chatRequest
            )
        )

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

            // 五行能量方向 + 性别审美区间
            let energyDescription = elementEnergyDescription(bazi.xiYongShen, soulmateGender: soulmateGender)

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

            ═══ image_prompt 视觉注入数据 ═══
            写 image_prompt 时参考以下数据：
            - 十神人设 → 决定表情和姿态
            - 夫妻星骨相 → 决定骨骼和体态
            - 五行能量方向 → 决定光线/环境的感受方向（服饰自由发挥）

            十神人设气质（\(bazi.dominantGod)）：\(personaText)\(spouseBlock)

            五行能量方向（\(bazi.xiYongShen)）：\(energyDescription)

            伴侣性别：\(soulmateGender)性
            伴侣视觉年龄：\(bazi.targetAge.map { "\($0)" } ?? "未知")岁

            image_prompt 必须保留完整的人物+场景描述，不得退化成通用肖像模板。末尾统一追加：电影感肖像，浅景深，肤质细节自然，色调自然克制，中性室内或城市背景\(visualAgeText)
            ═══════════════════════════════════

            用户基本信息：\(gender)性，\(birthDate)生，现居\(location)

            【强制规则】
            1. user_element 必须填"\(bazi.dayStemElement)"
            2. 伴侣必须是\(soulmateGender)性，全文用"\(pronounHeShe)"称呼
            3. 【不可覆写】soulmate_element 必须填"\(bazi.xiYongShen)"，禁止填其他五行
               - 你不得自行推算喜用神，系统已用调候算法精确计算
               - 视觉氛围（光线、环境）必须与「五行能量方向」一致
               - soulmateAppearance 的 skin_tone 应传递五行能量方向的感受，clothing 自由选择不受五行约束
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
            10. image_prompt 中：光影/环境 → 跟随「五行能量方向」；表情/姿态 → 跟随「十神人设」；骨骼/体态 → 跟随「夫妻星骨相」；服饰 → 自由发挥，追求多样性
            11. image_prompt 中人物面部必须符合目标年龄的真实外观，皮肤紧致光滑，禁止使用"成熟""沧桑""阅历""岁月沉淀"等老化词汇描述面部外观\(ageInstruction)
            12. image_prompt 中严禁描写瞳色或眼珠颜色，五行能量方向只影响光影/环境，不影响眼睛颜色和服饰。东亚人瞳色统一为自然深棕或黑褐色
            13. 避免使用易触发风控的超写实词：如"微米级/纳米级皮肤纹理""无滤镜真实感""毛孔细微可见""细纹清晰可见"，可替换为"肤质细节自然""自然人像风格"
            14. image_prompt 中发型必须全篇只出现一种长度（短发/中发/长发三选一），严禁在同一段描述中同时出现不同长度的发型词汇（例如禁止"寸头"和"垂肩长发"同时出现，禁止"平头"和"马尾"同时出现）

            请基于以上数据进行深度灵魂解析，伴侣五行已由系统确定，请严格执行。
            """
        } else {
            userMessage = """
            请根据以下信息分析这个人的性格特质，并推导出最适合的伴侣类型：

            用户信息：\(gender)性，\(birthDate) \(birthTime)生，现居\(location)

            伴侣必须是\(soulmateGender)性，全文用"\(pronounHeShe)"称呼。
            """
        }

        var chatRequest = ChatRequest(
            model: AppConfig.AliyunBailian.model,
            messages: [
                ChatRequest.Message(role: "system", content: soulAnalysisSystemPrompt),
                ChatRequest.Message(role: "user", content: userMessage)
            ],
            responseFormat: ChatRequest.ResponseFormat(type: "json_object")
        )
        // 注入 targetAge / xiYongShen / soulmateGender，供 aliyun-proxy EF 写入 prompt_tokens
        chatRequest.targetAge = baziInfo?.targetAge
        chatRequest.xiYongShen = baziInfo?.xiYongShen ?? ""
        chatRequest.soulmateGender = soulmateGender

        print("🔵 [TextGeneration] 发送灵魂分析请求到 aliyun-proxy Edge Function...")

        // 强制刷新 session，确保 accessToken 有效
        let efSession: Session
        do {
            efSession = try await supabase.auth.refreshSession()
            // 诊断：打印 token 过期时间
            let expiresAt = Date(timeIntervalSince1970: efSession.expiresAt)
            print("🔑 [TextGeneration] refreshSession 成功，token 过期时间: \(expiresAt), 距离过期: \(Int(efSession.expiresAt - Date().timeIntervalSince1970))秒")
        } catch {
            print("❌ [TextGeneration] refreshSession 失败: \(error) — 需要重新登录")
            NotificationCenter.default.post(name: .authSessionExpired, object: nil)
            throw error
        }

        let chatResponse: ChatResponse = try await supabase.functions.invoke(
            "aliyun-proxy",
            options: FunctionInvokeOptions(
                method: .post,
                headers: ["Authorization": "Bearer \(efSession.accessToken)"],
                body: chatRequest
            )
        )

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
        soulAnalysis.promptVersion = Self.soulAnalysisPromptVersion

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
        print("   - 分享金句: \(soulAnalysis.shareQuote ?? "（未生成）")")

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
