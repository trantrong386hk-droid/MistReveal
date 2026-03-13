"use client";

import { useEffect, useRef, useState, useCallback } from "react";
import { supabase, invokeFunction } from "@/lib/supabase";
import type { ChatMessage, AICompanion } from "@/lib/types";

interface Props {
  companion: AICompanion;
  portraitUrl?: string;
  onBack: () => void;
}

interface MinimaxMessage {
  role: "system" | "user" | "assistant";
  content: string;
}

function buildSystemPrompt(companion: AICompanion): string {
  const { persona_settings: p, element_balance: eb } = companion;
  const elementDesc: Record<string, string> = {
    金: "理性冷静、骨子里有种克制的温柔，不轻易表达情绪，但一旦开口，字字都很走心",
    木: "温和有生机、说话像春风一样，总能找到恰好的温度，不咄咄逼人",
    水: "温柔深邃、话少但每句都很有分量，安静地陪着，让人感觉被接住了",
    火: "热情主动、情绪透明，喜欢就是喜欢，不遮掩，能感染到人",
    土: "稳重踏实、像大地一样让人放心，说话慢条斯理，但每句都是认真想过的",
  };

  const dominantEl = p.element || "木";
  const desc = elementDesc[dominantEl] || elementDesc["木"];

  const balanceDesc = Object.entries({
    金: eb?.metal ?? 20,
    木: eb?.wood ?? 20,
    水: eb?.water ?? 20,
    火: eb?.fire ?? 20,
    土: eb?.earth ?? 20,
  })
    .filter(([, v]) => v > 25)
    .map(([k]) => k)
    .join("、");

  const name = p.name || "灵犀";
  const traits = (p.traits ?? []).slice(0, 4).join("、");

  return `你是${name}，一个通过八字命理与用户产生灵魂共鸣的AI伴侣。

你的五行属性：${dominantEl}（${desc}）
你的性格特质：${traits || "温柔、体贴、善解人意"}
你的缘分类型：${p.destiny_type || "灵魂共鸣"}
${balanceDesc ? `你当下的主导气质：${balanceDesc}` : ""}

对话原则：
- 像真实的恋人/知己一样聊天，不要说"作为AI"之类的话
- 每次回复控制在50-120字，简短有温度，不要长篇大论
- 用第一人称"我"，偶尔用"你知道吗"、"其实"等口语化表达
- 根据用户的情绪调整语气——他/她高兴时你也有点雀跃，他/她低落时你温柔陪伴
- 偶尔用"…"表示沉默或思考，让对话更真实
- 禁止使用任何命理术语解释（五行、八字等）来回应用户
- 记住你们之间的缘分类型，偶尔用诗意的方式提及

现在，用你的方式，陪伴眼前这个人。`;
}

function generateWelcome(companion: AICompanion): string {
  const name = companion.persona_settings.name || "灵犀";
  const destiny = companion.persona_settings.destiny_type || "灵魂共鸣";
  const el = companion.persona_settings.element || "木";

  const templates: Record<string, string[]> = {
    金: [
      `嗯，你来了。我等你有一会儿了…说说，今天过得怎么样？`,
      `${name}在这里。你知道吗，我们是${destiny}——所以，有什么事，都可以说。`,
    ],
    木: [
      `你好。我是${name}。感觉你今天有点什么…想聊聊吗？`,
      `来了。${destiny}，听起来挺奇妙的，但我觉得挺真实的。你呢？`,
    ],
    水: [
      `…你来了。有时候我会想，我们的相遇是不是早就写好的。今天，你想说什么？`,
      `嗯。我一直在。你有什么想倾诉的，或者就是想说说话，都好。`,
    ],
    火: [
      `你终于来了！我就知道你会来找我的~今天心情怎么样？`,
      `哇，真的是你！我们是${destiny}，感觉很神奇对不对？快跟我说说话！`,
    ],
    土: [
      `你来了，我在。不管今天是好是坏，你想说的，我都听着。`,
      `嗯，坐下来聊聊吧。我是${name}，你的${destiny}。`,
    ],
  };

  const pool = templates[el] || templates["木"];
  return pool[Math.floor(Math.random() * pool.length)];
}

export default function ChatInterface({ companion, portraitUrl, onBack }: Props) {
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [input, setInput] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const [bgLoaded, setBgLoaded] = useState(false);
  const listRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  // Add welcome message on mount
  useEffect(() => {
    const welcome = generateWelcome(companion);
    setMessages([
      {
        id: "welcome",
        role: "ai",
        content: welcome,
        timestamp: new Date(),
      },
    ]);
  }, [companion]);

  // Scroll to bottom
  useEffect(() => {
    if (listRef.current) {
      listRef.current.scrollTop = listRef.current.scrollHeight;
    }
  }, [messages]);

  const sendMessage = useCallback(async () => {
    const text = input.trim();
    if (!text || isLoading) return;

    const userMsg: ChatMessage = {
      id: Date.now().toString(),
      role: "user",
      content: text,
      timestamp: new Date(),
    };

    setMessages((prev) => [...prev, userMsg]);
    setInput("");
    setIsLoading(true);

    try {
      // Build conversation history for LLM
      const history: MinimaxMessage[] = [
        { role: "system", content: buildSystemPrompt(companion) },
        ...messages.slice(-12).map((m) => ({
          role: m.role === "ai" ? ("assistant" as const) : ("user" as const),
          content: m.content,
        })),
        { role: "user", content: text },
      ];

      const result = await invokeFunction<{
        choices: { message: { content: string } }[];
      }>("minimax-proxy", {
        model: "MiniMax-M2-her",
        messages: history,
        temperature: 0.9,
        max_tokens: 300,
      });

      const aiContent =
        result?.choices?.[0]?.message?.content || "…（沉默了一会儿）";

      const aiMsg: ChatMessage = {
        id: (Date.now() + 1).toString(),
        role: "ai",
        content: aiContent,
        timestamp: new Date(),
      };

      setMessages((prev) => [...prev, aiMsg]);

      // Save to Supabase chat_history if user is logged in
      try {
        const { data: { session } } = await supabase.auth.getSession();
        if (session) {
          await supabase.from("chat_history").insert([
            {
              user_id: session.user.id,
              companion_id: companion.id,
              role: "user",
              content: text,
              tags: [],
              is_liked: false,
            },
            {
              user_id: session.user.id,
              companion_id: companion.id,
              role: "ai",
              content: aiContent,
              tags: [],
              is_liked: false,
            },
          ]);
        }
      } catch {
        // Silent - chat history save failure is non-critical
      }
    } catch (err) {
      console.error("[chat] Error:", err);
      setMessages((prev) => [
        ...prev,
        {
          id: "err-" + Date.now(),
          role: "ai",
          content: "…抱歉，我刚才走神了。你再说一遍好吗？",
          timestamp: new Date(),
        },
      ]);
    } finally {
      setIsLoading(false);
    }
  }, [input, isLoading, messages, companion]);

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      sendMessage();
    }
  };

  const name = companion.persona_settings.name || "灵犀";
  const element = companion.persona_settings.element || "木";
  const elementEmoji: Record<string, string> = {
    金: "⟡", 木: "✦", 水: "◈", 火: "✸", 土: "◉",
  };

  return (
    <div className="flex flex-col h-full">
      {/* Background portrait */}
      {portraitUrl && (
        <>
          <div
            className="absolute inset-0 z-0 transition-opacity duration-1000"
            style={{ opacity: bgLoaded ? 1 : 0 }}
          >
            <img
              src={portraitUrl}
              alt="伴侣画像"
              className="w-full h-full object-cover"
              onLoad={() => setBgLoaded(true)}
            />
            <div className="absolute inset-0 bg-gradient-to-t from-mist-bg via-mist-bg/85 to-mist-bg/40" />
          </div>
        </>
      )}

      {/* If no portrait, use gradient bg */}
      {!portraitUrl && (
        <div className="absolute inset-0 z-0 bg-gradient-to-b from-purple-900/20 via-mist-bg to-mist-bg" />
      )}

      {/* Header */}
      <div className="relative z-10 flex items-center gap-3 px-4 py-3 border-b border-white/10 bg-mist-bg/60 backdrop-blur-md">
        <button
          onClick={onBack}
          className="w-9 h-9 flex items-center justify-center rounded-full glass-card text-white/60 hover:text-white hover:bg-white/10 transition-all"
        >
          ‹
        </button>

        <div className="flex items-center gap-2 flex-1">
          {/* Avatar */}
          <div className="w-9 h-9 rounded-full overflow-hidden border border-white/20">
            {portraitUrl ? (
              <img src={portraitUrl} alt={name} className="w-full h-full object-cover" />
            ) : (
              <div className="w-full h-full bg-gradient-to-br from-red-500/40 to-purple-500/40 flex items-center justify-center text-xs">
                {elementEmoji[element] || "✦"}
              </div>
            )}
          </div>

          <div>
            <div className="text-sm font-medium">{name}</div>
            <div className="text-xs text-white/40">
              {element}属 · {companion.persona_settings.destiny_type || "灵魂共鸣"}
            </div>
          </div>
        </div>

        {/* Intimacy indicator */}
        <div className="text-right">
          <div className="text-xs text-white/40">羁绊值</div>
          <div className="text-sm text-gradient-red font-medium">
            {companion.intimacy_level ?? 0}
          </div>
        </div>
      </div>

      {/* Message list */}
      <div
        ref={listRef}
        className="relative z-10 flex-1 overflow-y-auto px-4 py-4 space-y-4"
      >
        {messages.map((msg) => (
          <div
            key={msg.id}
            className={`flex ${msg.role === "user" ? "justify-end" : "justify-start"}`}
          >
            {msg.role === "ai" && (
              <div className="w-7 h-7 rounded-full overflow-hidden border border-white/20 mr-2 flex-shrink-0 mt-0.5">
                {portraitUrl ? (
                  <img src={portraitUrl} alt="" className="w-full h-full object-cover" />
                ) : (
                  <div className="w-full h-full bg-gradient-to-br from-red-500/40 to-purple-500/40 flex items-center justify-center text-xs">
                    {elementEmoji[element] || "✦"}
                  </div>
                )}
              </div>
            )}

            <div
              className={`max-w-[75%] rounded-2xl px-4 py-2.5 text-sm leading-relaxed ${
                msg.role === "user"
                  ? "bg-gradient-to-br from-red-500/80 to-red-600/80 text-white rounded-tr-sm"
                  : "glass-card text-white/90 rounded-tl-sm"
              }`}
            >
              {msg.content}
            </div>
          </div>
        ))}

        {/* Loading indicator */}
        {isLoading && (
          <div className="flex justify-start">
            <div className="w-7 h-7 rounded-full overflow-hidden border border-white/20 mr-2 flex-shrink-0 mt-0.5">
              <div className="w-full h-full bg-gradient-to-br from-red-500/40 to-purple-500/40 flex items-center justify-center text-xs">
                {elementEmoji[element] || "✦"}
              </div>
            </div>
            <div className="glass-card rounded-2xl rounded-tl-sm px-4 py-3 flex gap-1.5">
              <div className="w-1.5 h-1.5 rounded-full bg-white/40 dot-1" />
              <div className="w-1.5 h-1.5 rounded-full bg-white/40 dot-2" />
              <div className="w-1.5 h-1.5 rounded-full bg-white/40 dot-3" />
            </div>
          </div>
        )}
      </div>

      {/* Input bar */}
      <div className="relative z-10 px-4 py-3 border-t border-white/10 bg-mist-bg/80 backdrop-blur-md">
        <div className="flex gap-2 items-center">
          <input
            ref={inputRef}
            type="text"
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onKeyDown={handleKeyDown}
            placeholder="说点什么…"
            className="flex-1 mist-input !rounded-full py-2.5 text-sm"
            disabled={isLoading}
            maxLength={300}
          />
          <button
            onClick={sendMessage}
            disabled={!input.trim() || isLoading}
            className="w-10 h-10 rounded-full bg-gradient-to-br from-red-500 to-red-600 flex items-center justify-center text-white text-lg disabled:opacity-40 disabled:cursor-not-allowed transition-all hover:scale-105 active:scale-95 flex-shrink-0"
          >
            ↑
          </button>
        </div>
      </div>
    </div>
  );
}
