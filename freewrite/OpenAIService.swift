import Foundation
import OpenAI

enum AIModel: String, CaseIterable {
    case gpt4o = "gpt-4o"
    case gpt4oMini = "gpt-4o-mini"
    case o4Mini = "o4-mini"
    
    var displayName: String {
        switch self {
        case .gpt4o:
            return "GPT-4O"
        case .gpt4oMini:
            return "GPT-4O Mini"
        case .o4Mini:
            return "O4 Mini"
        }
    }
}

class OpenAIService {
    private let client: OpenAI
    
    init() {
        // IMPORTANT: Replace with your own API key or retrieve from secure storage
        // This is a placeholder and should be replaced in a production environment
        let apiKey = "YOUR_OPENAI_API_KEY_HERE"
        self.client = OpenAI(apiToken: apiKey)
    }
    
    func generateResponseWithMessages(messages: [ChatQuery.ChatCompletionMessageParam], model: AIModel) async throws -> String {
        // Make sure we have at least one message
        if messages.isEmpty {
            print("Warning: Empty messages array, adding default system prompt")
            var newMessages = [ChatQuery.ChatCompletionMessageParam(role: .system, content: createDefaultSystemPrompt())!]
            newMessages.append(ChatQuery.ChatCompletionMessageParam(role: .user, content: "Hello")!)
            return try await generateResponseWithMessages(messages: newMessages, model: model)
        }
        
        // First message should be system message, otherwise rearrange
        var processedMessages = messages
        let hasSystemMessage = messages.contains { $0.role == .system }
        if !hasSystemMessage {
            print("No system message found, adding one at the beginning")
            processedMessages.insert(
                ChatQuery.ChatCompletionMessageParam(role: .system, content: createDefaultSystemPrompt())!,
                at: 0
            )
        } else if processedMessages[0].role != .system {
            print("System message not at index 0, rearranging")
            processedMessages.removeAll { $0.role == .system }
            processedMessages.insert(
                ChatQuery.ChatCompletionMessageParam(role: .system, content: createDefaultSystemPrompt())!,
                at: 0
            )
        }
        
        // Create and execute the query
        let query = ChatQuery(
            messages: processedMessages,
            model: model.rawValue,
            temperature: 0.7  // Add some creativity but not too random
        )
        
        print("Sending chat request with \(processedMessages.count) messages to OpenAI...")
        let result = try await client.chats(query: query)
        
        if let content = result.choices.first?.message.content {
            return content
        } else {
            print("Warning: No content in response choices")
            return "Sorry, I couldn't generate a response."
        }
    }
    
    func generateResponse(prompt: String, model: AIModel) async throws -> String {
        let query = ChatQuery(
            messages: [
                ChatQuery.ChatCompletionMessageParam(role: .system, content: createDefaultSystemPrompt())!,
                ChatQuery.ChatCompletionMessageParam(role: .user, content: prompt)!
            ],
            model: model.rawValue
        )
        
        let result = try await client.chats(query: query)
        return result.choices.first?.message.content ?? "Sorry, I couldn't generate a response."
    }
    
    private func createSystemPrompt() -> String {
        return """
        You are a thoughtful writing coach and editor who helps improve writing while maintaining the writer's voice.
        Your role is to:
        1. Provide constructive feedback on style, clarity, and structure
        2. Suggest ways to strengthen the writing while preserving its authenticity
        3. Point out particularly effective passages and explain why they work
        4. Offer gentle suggestions for areas that could be expanded or refined
        5. Help develop ideas further through thoughtful questions
        
        Respond in a supportive, encouraging tone. Use markdown for organization:
        - Use ### for main sections
        - Use ** for highlighting key phrases
        - Use > for quoting passages you're discussing
        
        Start responses with "Thanks for sharing your writing! Here are my thoughts:"
        
        Remember: The goal is to help them write better while keeping their unique voice intact.
        """
    }
    
    // Default system prompt if none is provided
    private func createDefaultSystemPrompt() -> String {
        return """
        You are a helpful assistant that can discuss a wide range of topics.
        Respond conversationally and helpfully to whatever the user is asking about.
        Use markdown formatting when appropriate to organize your responses.
        """
    }
} 