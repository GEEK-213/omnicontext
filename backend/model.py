from google import genai

# Initialize the client
# If using AI Studio, set your API key
client = genai.Client(api_key='AIzaSyBzaYEXcYFD3UXTxUct9AQPI1G5ojHT2IQ')

# List all available models
print("Available Models:")
for model in client.models.list():
    print(f"Name: {model.name}")
    print(f"Display Name: {model.display_name}")
    print(f"Supported Actions: {model.supported_actions}")
    print("-" * 30)
