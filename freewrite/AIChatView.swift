import SwiftUI
import OpenAI

// Structure to hold a chat message
struct ChatMessage: Identifiable, CustomStringConvertible {
    let id = UUID()
    let role: ChatQuery.ChatCompletionMessageParam.Role
    let content: String
    let timestamp = Date()
    
    var description: String {
        "ChatMessage(role: \(role.rawValue), content: \(content.prefix(20))..., timestamp: \(timestamp))"
    }
}

struct AIChatView: View {
    // Binding to the main editor text - kept for potential future use or context
    @Binding var text: String 
    
    // State for chat functionality
    @State private var chatMessages: [ChatMessage] = []
    @State private var currentInput: String = ""
    @State private var isLoading: Bool = false
    @State private var selectedModel: AIModel = .gpt4oMini
    @State private var error: String? = nil
    
    private let openAIService = OpenAIService()
    @Environment(\.colorScheme) private var colorScheme
    
    private var textColor: Color {
        colorScheme == .light ? Color(red: 0.20, green: 0.20, blue: 0.20) : Color(red: 0.9, green: 0.9, blue: 0.9)
    }
    
    private var backgroundColor: Color {
        colorScheme == .light ? Color.white : Color.black
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with Model Selector
            HStack {
                Picker("Model", selection: $selectedModel) {
                    ForEach(AIModel.allCases, id: \.self) { model in
                        Text(model.displayName).tag(model)
                    }
                }
                .pickerStyle(.menu)
                .font(.system(size: 13))
                .frame(width: 120)
                
                Spacer()
                
                // Optional: Button to use editor content as input
                Button {
                    currentInput = text // Load editor text into input field
                } label: {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 13))
                        .foregroundColor(colorScheme == .light ? .gray : .gray.opacity(0.8))
                }
                .buttonStyle(.plain)
                .help("Load editor content")
                .padding(.trailing, 8)
                
                // Clear Chat Button
                Button {
                    chatMessages = []
                    error = nil
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13))
                        .foregroundColor(colorScheme == .light ? .gray : .gray.opacity(0.8))
                }
                .buttonStyle(.plain)
                .help("Clear chat history")
                
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(backgroundColor)
            
            Divider()
                .opacity(0.4)
            
            // Chat History Area
            ScrollViewReader { scrollViewProxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if chatMessages.isEmpty {
                            VStack(spacing: 20) {
                                Spacer()
                                Image(systemName: "bubble.left.and.bubble.right")
                                    .font(.system(size: 48))
                                    .foregroundColor(Color.gray.opacity(0.4))
                                
                                Text("Ask a question or select text from your writing for feedback.")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color.gray.opacity(0.7))
                                    .multilineTextAlignment(.center)
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding()
                        } else {
                            ForEach(chatMessages) { message in
                                ChatBubble(message: message)
                                    .id(message.id)
                            }
                            
                            if isLoading {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .padding(.vertical, 5)
                                    Spacer()
                                }
                            }
                            
                            if let error = error {
                                Text(error)
                                    .font(.system(size: 13))
                                    .foregroundColor(.red)
                                    .padding()
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 16)
                }
                .background(backgroundColor)
                .onChange(of: chatMessages.count) { _ in
                    // Scroll to the bottom when new messages are added
                    if let lastMessage = chatMessages.last {
                        withAnimation {
                            scrollViewProxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            Divider()
                .opacity(0.4)
            
            // Input Area
            HStack(spacing: 12) {
                TextField("Type your message here...", text: $currentInput, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .frame(minHeight: 36)
                    .padding(.horizontal, 12)
                    .lineLimit(1...5)
                    .foregroundColor(textColor)
                    .background(colorScheme == .light ? Color.gray.opacity(0.05) : Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                    .onSubmit {
                        let trimmedInput = currentInput.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmedInput.isEmpty && !isLoading {
                            sendMessage()
                        }
                    }
                    // Enable/disable enter key submission based on content
                    .submitLabel(currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .return : .send)
                    
                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading ? 
                                         Color.gray.opacity(0.3) : 
                                         colorScheme == .light ? .blue : .blue.opacity(0.8))
                }
                .buttonStyle(.plain)
                .disabled(currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(backgroundColor)
        }
    }
    
    // Function to handle sending messages and getting responses
    private func sendMessage() {
        guard !currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // Create and add user message to chat history
        let userMessageContent = currentInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let userMessage = ChatMessage(role: .user, content: userMessageContent)
        chatMessages.append(userMessage)
        currentInput = ""
        error = nil
        isLoading = true
        
        Task {
            do {
                // Create a clean conversation for the API
                var apiMessages: [ChatQuery.ChatCompletionMessageParam] = []
                
                // 1. First message is always system prompt
                apiMessages.append(ChatQuery.ChatCompletionMessageParam(role: .system, content: createSystemPrompt())!)
                
                // 2. Add all user/assistant exchanges from the chat history
                for msg in chatMessages {
                    apiMessages.append(ChatQuery.ChatCompletionMessageParam(role: msg.role, content: msg.content)!)
                }
                
                // Debug conversation being sent
                print("Sending conversation with \(apiMessages.count) messages:")
                for (i, msg) in apiMessages.enumerated() {
                    let contentPreview = msg.content != nil ? String(describing: msg.content).prefix(30) : "nil"
                    print("[\(i)] \(msg.role.rawValue): \(contentPreview)...")
                }
                
                // Generate response from OpenAI
                let responseContent = try await openAIService.generateResponseWithMessages(messages: apiMessages, model: selectedModel)
                
                // Create and add assistant message to chat history
                let aiMessage = ChatMessage(role: .assistant, content: responseContent)
                chatMessages.append(aiMessage)
                
            } catch {
                self.error = "Error: \(error.localizedDescription)"
                print("Chat API Error: \(error)")
            }
            
            isLoading = false
        }
    }
    
    // Helper to create the system prompt (extracted from OpenAIService for clarity)
    private func createSystemPrompt() -> String {
        return """
        You are a helpful assistant that can discuss a wide range of topics. 
        
        If the user shares any writing or asks for writing feedback, you should:
        1. Provide constructive feedback on style, clarity, and structure
        2. Suggest ways to strengthen the writing while preserving authenticity
        3. Point out effective passages and explain why they work
        4. Offer gentle suggestions for areas that could be expanded or refined
        
        For all other types of queries, respond conversationally and helpfully to whatever the user is asking about.
        
        Use markdown formatting when appropriate to organize your responses.
        """
    }
}

// Simple Chat Bubble View
struct ChatBubble: View {
    let message: ChatMessage
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(alignment: .top) {
            if message.role == .user {
                Spacer()
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 0) {
                Text(message.role == .user ? "You" : "AI")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(message.role == .user ? 
                                     Color.blue.opacity(0.7) : 
                                     colorScheme == .light ? Color.gray.opacity(0.8) : Color.gray.opacity(0.7))
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                
                // Use markdown rendering for the message content
                Text(.init(message.content))
                    .font(.system(size: 14))
                    .textSelection(.enabled)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
                    .foregroundColor(textColor)
                    .frame(maxWidth: 280, alignment: message.role == .user ? .trailing : .leading)
            }
            .background(bubbleBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.1), lineWidth: 1)
            )
            
            if message.role == .assistant {
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }
    
    private var bubbleBackground: Color {
        switch message.role {
        case .user:
            return colorScheme == .light ? 
                Color.blue.opacity(0.1) : 
                Color.blue.opacity(0.15)
        case .assistant:
            return colorScheme == .light ? 
                Color.gray.opacity(0.08) : 
                Color.gray.opacity(0.15)
        default:
            return Color.orange.opacity(0.1)
        }
    }
    
    private var textColor: Color {
        colorScheme == .light ? Color(red: 0.20, green: 0.20, blue: 0.20) : Color(red: 0.9, green: 0.9, blue: 0.9)
    }
}


// Update Preview if needed
#Preview {
    // Need a dummy binding for preview
    @State var dummyText: String = "Sample text for context"
    return AIChatView(text: $dummyText)
        .frame(width: 320, height: 500)
} 