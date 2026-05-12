import keyboard
from pynput import mouse
import sys

print("--- Mouse Logger Started ---")
print("Click anywhere to see pixel locations.")
print("Press 'SHIFT' to stop the script.")

def on_click(x, y, button, pressed):
    if pressed:
        # Check if the click is on the left side (x < 0) 
        # Note: This depends on your specific Windows/OS display settings
        print(f"Mouse clicked at: ({x}, {y})")

# Set up the listener
listener = mouse.Listener(on_click=on_click)
listener.start()

# Keep the script running until Shift is pressed
keyboard.wait('shift')

print("\nShift detected. Exiting...")
listener.stop()
sys.exit()
