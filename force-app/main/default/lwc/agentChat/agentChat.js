import { LightningElement } from "lwc";
import { subscribe, unsubscribe, onError } from "lightning/empApi";
import startAgent from "@salesforce/apex/AgentController.startAgent";
import stopAgent from "@salesforce/apex/AgentController.stopAgent";

export default class AgentChat extends LightningElement {
  messages = [];
  currentSteps = [];
  inputValue = "";
  sessionId;
  subscription;
  isLoading = false;
  conversationHistory = [];
  _messageCounter = 0;

  connectedCallback() {
    this.registerErrorListener();
    this.subscribeToEvents();
  }

  disconnectedCallback() {
    if (this.subscription) {
      unsubscribe(this.subscription);
    }
  }

  registerErrorListener() {
    onError((error) => {
      console.error("empApi error:", JSON.stringify(error));
    });
  }

  subscribeToEvents() {
    if (!subscribe) {
      console.error("empApi subscribe not available");
      return;
    }

    subscribe("/event/AgentStep__e", -1, (response) => {
      this.handleAgentStep(response);
    })
      .then((response) => {
        this.subscription = response;
      })
      .catch((error) => {
        console.error("Failed to subscribe to AgentStep__e:", error);
      });
  }

  handleAgentStep(message) {
    const p = message.data.payload;
    if (p.SessionId__c !== this.sessionId) {
      return;
    }

    if (p.Status__c === "IN_PROGRESS") {
      if (p.Utterance__c || p.Thought__c) {
        this.currentSteps = [
          ...this.currentSteps,
          {
            id: ++this._messageCounter,
            headerText: p.Utterance__c || "Thought",
            thought: p.Thought__c || null,
            showThought: false
          }
        ];
        this.scrollToBottom();
      }
    } else if (p.Status__c === "ERROR") {
      this.messages = [
        ...this.messages,
        {
          id: ++this._messageCounter,
          role: "assistant",
          messageClass: "message message-assistant message-error",
          content: p.Answer__c || "An unknown error occurred",
          steps: [...this.currentSteps]
        }
      ];
      this.currentSteps = [];
      this.isLoading = false;
      this.scrollToBottom();
    } else {
      this.messages = [
        ...this.messages,
        {
          id: ++this._messageCounter,
          role: "assistant",
          messageClass: "message message-assistant",
          content: p.Answer__c,
          steps: [...this.currentSteps]
        }
      ];
      this.conversationHistory.push({
        role: "assistant",
        content: p.Answer__c
      });
      this.currentSteps = [];
      this.isLoading = false;
      this.scrollToBottom();
    }
  }

  toggleThought(event) {
    const stepId = Number(event.currentTarget.dataset.id);

    this.currentSteps = this.currentSteps.map((step) =>
      step.id === stepId
        ? { ...step, showThought: !step.showThought }
        : step
    );

    this.messages = this.messages.map((msg) => ({
      ...msg,
      steps: msg.steps.map((step) =>
        step.id === stepId
          ? { ...step, showThought: !step.showThought }
          : step
      )
    }));
  }

  handleInputChange(e) {
    this.inputValue = e.target.value;
  }

  handleKeyDown(e) {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      this.handleSend();
    }
  }

  generateSessionId() {
    const array = new Uint8Array(16);
    crypto.getRandomValues(array);
    return Array.from(array, (b) => b.toString(16).padStart(2, "0")).join("");
  }

  async handleSend() {
    const msg = this.inputValue.trim();
    if (!msg || this.isLoading) return;

    this.messages = [
      ...this.messages,
      {
        id: ++this._messageCounter,
        role: "user",
        messageClass: "message message-user",
        content: msg,
        steps: []
      }
    ];
    this.conversationHistory.push({
      role: "user",
      content: msg
    });
    this.inputValue = "";
    this.isLoading = true;
    this.currentSteps = [];
    this.scrollToBottom();

    if (!this.sessionId) {
      this.sessionId = this.generateSessionId();
    }

    try {
      await startAgent({
        sessionId: this.sessionId,
        userMessage: msg,
        conversationHistoryJson: JSON.stringify(this.conversationHistory)
      });
    } catch (error) {
      console.error("startAgent error:", error);
      this.isLoading = false;
      this.messages = [
        ...this.messages,
        {
          id: ++this._messageCounter,
          role: "assistant",
          messageClass: "message message-assistant message-error",
          content:
            "Error: " +
            (error.body?.message || error.message || "Unknown error"),
          steps: []
        }
      ];
      this.scrollToBottom();
    }
  }

  async handleStop() {
    if (!this.sessionId) return;

    try {
      await stopAgent({ sessionId: this.sessionId });
    } catch (error) {
      console.error("stopAgent error:", error);
    }
  }

  scrollToBottom() {
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    setTimeout(() => {
      const chatWindow = this.refs.chatWindow;
      if (chatWindow) {
        chatWindow.scrollTop = chatWindow.scrollHeight;
      }
    }, 0);
  }
}