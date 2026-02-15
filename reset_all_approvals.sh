#! /bin/bash

echo "Resetting all permissions for WhisperClip..."

# Reset all permissions
echo "Resetting all TCC permissions..."
sudo tccutil reset All com.whisperclip
sudo tccutil reset All WhisperClip

# Reset specific permissions (more targeted approach)
echo "Resetting specific permissions..."
sudo tccutil reset Microphone com.whisperclip
sudo tccutil reset Accessibility com.whisperclip
sudo tccutil reset AppleEvents com.whisperclip
sudo tccutil reset ListenEvent com.whisperclip
sudo tccutil reset Microphone WhisperClip
sudo tccutil reset Accessibility WhisperClip
sudo tccutil reset AppleEvents WhisperClip
sudo tccutil reset ListenEvent WhisperClip

echo "Permissions have been reset. Please restart the app."
echo "Note: You may need to restart your computer for changes to take full effect."
