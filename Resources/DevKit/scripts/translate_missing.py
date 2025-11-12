#!/usr/bin/env python3
"""
Automatically translate strings where English and Chinese values are identical.
Uses manual translation mappings defined in TRANSLATION_MAP.

Usage:
    python3 translate_missing.py [path/to/Localizable.xcstrings]
    
If no path is provided, defaults to FlowDown/Resources/Localizable.xcstrings

This script will:
1. Find strings where English and Chinese values are identical (untranslated)
2. Look up translations in the TRANSLATION_MAP
3. Apply translations and update the file
4. Report how many strings were translated and how many are still missing

To add new translations, update the TRANSLATION_MAP dictionary below.
"""

import json
import sys
import os

# Manual translation map for common strings
TRANSLATION_MAP = {
    "(Reasoning) %@": "（推理中）%@",
    "Add text, images, or audio to the rich editor's temporary storage for the selected conversation.": "为所选对话的富文本编辑器临时存储添加文本、图像或音频。",
    "Browse and select any FlowDown conversation.": "浏览并选择任意 FlowDown 对话。",
    "Ask Model": "询问模型",
    "Ask Model + Image": "询问模型 + 图像",
    "Ask Model + Image + Tools": "询问模型 + 图像 + 工具",
    "Ask Model + Tools": "询问模型 + 工具",
    "Assistant": "助手",
    "Built-in Tool": "内置工具",
    "Choose from the models available in FlowDown.": "选择 FlowDown 中可用的模型。",
    "Classification": "分类",
    "Conversations": "对话",
    "Cloud": "云端",
    "Content": "内容",
    "Create conversation": "创建对话",
    "Create Conversation": "创建对话",
    "Create a deep link that starts a new conversation in the app.": "创建在应用内启动新对话的深度链接。",
    "Create a new conversation and optionally switch to it.": "创建一个新对话，并可选择切换到该对话。",
    "Disable all FlowDown tools": "禁用所有 FlowDown 工具",
    "Disable All Tools": "禁用所有工具",
    "Disabled built-in tools: %1$lld. Skipped: %2$lld. MCP servers disabled: %3$lld of %4$lld.": "已禁用内置工具：%1$lld 个。跳过：%2$lld 个。已禁用 MCP 服务器：%3$lld / %4$lld。",
    "Discord": "Discord",
    "Enable ${tool}": "启用 ${tool}",
    "Enable a specific FlowDown tool or MCP server.": "启用特定的 FlowDown 工具或 MCP 服务器。",
    "Enable all FlowDown tools": "启用所有 FlowDown 工具",
    "Enable All Tools": "启用所有工具",
    "Enable every built-in tool and all MCP servers.": "启用所有内置工具和所有 MCP 服务器。",
    "Enable Tool": "启用工具",
    "Enabled built-in tools: %1$lld. Skipped: %2$lld. MCP servers enabled: %3$lld of %4$lld.": "已启用内置工具：%1$lld 个。跳过：%2$lld 个。已启用 MCP 服务器：%3$lld / %4$lld。",
    "Enabled MCP server: %@": "已启用 MCP 服务器：%@",
    "Enabled tool: %@": "已启用工具：%@",
    "Failed to launch FlowDown.": "无法启动 FlowDown。",
    "Fetch Last Conversation": "获取最近的对话",
    "Fetch latest conversation details": "获取最新对话详情",
    "FlowDown": "FlowDown",
    "FlowDown launched to start a new conversation.": "已启动 FlowDown 以开始新对话。",
    "FlowDown launched with your message.": "已启动 FlowDown 并发送您的消息。",
    "GitHub": "GitHub",
    "Generation": "生成",
    "Image": "图像",
    "Improve Writing - Concise": "改进写作 - 简洁",
    "Improve Writing - Friendly": "改进写作 - 友好",
    "Improve Writing - Professional": "改进写作 - 专业",
    "Initial Message": "初始消息",
    "Local": "本地",
    "No conversations were found.": "未找到任何对话。",
    "Launch FlowDown without performing any additional actions.": "启动 FlowDown 而不执行其他操作。",
    "Open FlowDown and optionally start a conversation with a message.": "打开 FlowDown，可选择使用消息开始对话。",
    "Original Text:": "原文：",
    "Quick Reply": "快速回复",
    "Quick Reply with Image": "快速回复（带图像）",
    "Quick Reply with Image & Tools": "快速回复（带图像和工具）",
    "Quick Reply with Image and Tools": "快速回复（带图像和工具）",
    "Quick Reply with Tools": "快速回复（带工具）",
    "Return the full transcript of the most recent FlowDown conversation.": "返回最近一次 FlowDown 对话的完整记录。",
    "Return the full document of the most recent conversation.": "返回最近一次对话的完整文档。",
    "Rewrite concise ${text}": "简洁改写 ${text}",
    "Rewrite friendly ${text}": "友好改写 ${text}",
    "Rewrite professionally ${text}": "专业改写 ${text}",
    "Rewrite text in a more professional tone while preserving meaning.": "以更专业的语气改写文本，同时保留原意。",
    "Rewrite text with a warmer and more approachable tone.": "以更温暖、更亲切的语气改写文本。",
    "Rewrite the following content so it reads professional, confident, and concise while preserving the original meaning. Reply with the revised text only.": "改写以下内容，使其读起来专业、自信、简洁，同时保留原意。只回复修改后的文本。",
    "Rewrite the following content to be more concise and direct while keeping essential details. Reply with the revised text only.": "将以下内容改写得更简洁、更直接，同时保留关键细节。只回复修改后的文本。",
    "Rewrite the following content to sound warm, friendly, and easy to understand while keeping the same intent. Reply with the revised text only.": "将以下内容改写得温暖、友好、易于理解，同时保持相同的意图。只回复修改后的文本。",
    "Select an image to include.": "选择要包含的图像。",
    "Send a message with an image and get the model's response.": "发送带图像的消息并获取模型的回复。",
    "Send a message with an image, allow tools, and get the response.": "发送带图像的消息，允许使用工具，并获取回复。",
    "Send a message, allow model tools, and get the response.": "发送消息，允许使用模型工具，并获取回复。",
    "Source Text:": "原文：",
    "Summarize ${text}": "总结 ${text}",
    "Summarize as list ${text}": "列表总结 ${text}",
    "Summarize content into a list of key points.": "将内容总结为关键要点列表。",
    "Summarize content into a short paragraph.": "将内容总结为简短段落。",
    "Summarize Text": "总结文本",
    "Summarize Text as List": "列表总结文本",
    "Summarize the following content into a concise paragraph that captures the main ideas. Reply with the summary only.": "将以下内容总结为简洁的段落，概括主要思想。只回复总结内容。",
    "Summarize the following content into a list of short bullet points that highlight the essential facts. Reply with the bullet list only.": "将以下内容总结为简短要点列表，突出关键事实。只回复要点列表。",
    "The latest conversation does not contain any messages.": "最近的对话不包含任何消息。",
    "The provided image could not be processed.": "无法处理提供的图像。",
    "The selected MCP server could not be located.": "找不到所选的 MCP 服务器。",
    "The selected model does not support image inputs.": "所选模型不支持图像输入。",
    "The selected model does not support tool calls.": "所选模型不支持工具调用。",
    "The selected tool could not be located.": "找不到所选的工具。",
    "This shortcut does not accept images.": "此快捷指令不接受图像。",
    "Trim text to be more concise without losing the key message.": "精简文本使其更简洁，同时不失关键信息。",
    "Switch to a conversation and automatically send the message.": "切换到对话并自动发送消息。",
    "Switch to a conversation without sending any messages.": "切换到对话而不发送任何消息。",
    "Transcription": "转录",
    "Turn off every built-in tool and all MCP servers.": "关闭所有内置工具和所有 MCP 服务器。",
    "Unable to construct FlowDown URL.": "无法构建 FlowDown URL。",
    "Unable to encode the provided message.": "无法编码提供的消息。",
    "Utilities": "实用工具",
    "User": "用户",
    "What message should FlowDown use to start the chat?": "FlowDown 应该使用什么消息来开始对话？",
    "What text should be rewritten?": "应该改写什么文本？",
    "What text should be summarized?": "应该总结什么文本？",
    "Which model should rewrite the text?": "应该使用哪个模型来改写文本？",
    "Which model should summarize the text?": "应该使用哪个模型来总结文本？",
    "Which tool should be enabled?": "应该启用哪个工具？",
    "Writing Assistance": "写作辅助",
}

def translate_missing(file_path):
    """Translate strings where en and zh-Hans have identical values."""
    
    # Read the file
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except FileNotFoundError:
        print(f"❌ File not found: {file_path}")
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"❌ JSON decode error in {file_path}: {e}")
        sys.exit(1)
    
    strings = data['strings']
    translated_count = 0
    missing_count = 0
    
    # Check each string
    for key, value in strings.items():
        # Skip strings marked as shouldTranslate=false
        if not value.get('shouldTranslate', True):
            continue
        
        locs = value.get('localizations', {})
        
        # Check if both en and zh-Hans exist
        if 'en' in locs and 'zh-Hans' in locs:
            en_value = locs['en'].get('stringUnit', {}).get('value', '')
            zh_value = locs['zh-Hans'].get('stringUnit', {}).get('value', '')
            
            # If values are identical and not empty, it needs translation
            if en_value and zh_value and en_value == zh_value:
                # Check if we have a translation
                if en_value in TRANSLATION_MAP:
                    locs['zh-Hans']['stringUnit']['value'] = TRANSLATION_MAP[en_value]
                    translated_count += 1
                    print(f"✅ Translated: {key}")
                else:
                    missing_count += 1
                    print(f"⚠️  Missing translation for: {key} = {en_value}")
    
    # Write the updated file
    if translated_count > 0:
        try:
            with open(file_path, 'w', encoding='utf-8') as f:
                json.dump(data, f, ensure_ascii=False, indent=2)
            print(f"\n✅ Successfully updated {file_path}")
            print(f"   - Translated: {translated_count} strings")
            print(f"   - Missing translations: {missing_count} strings")
            return True
        except Exception as e:
            print(f"❌ Error writing file: {e}")
            sys.exit(1)
    else:
        print(f"\n⚠️  No translations applied")
        print(f"   - Missing translations: {missing_count} strings")
        return False

if __name__ == '__main__':
    # Default path to the Localizable.xcstrings file
    default_file_path = os.path.abspath(
        os.path.join(
            os.path.dirname(__file__),
            '..',
            '..',
            '..',
            'FlowDown',
            'Resources',
            'Localizable.xcstrings',
        )
    )
    
    # Allow overriding the file path via command line argument
    file_path = sys.argv[1] if len(sys.argv) > 1 else default_file_path
    
    print(f"📝 Translating missing strings in: {file_path}")
    print()
    
    translate_missing(file_path)

