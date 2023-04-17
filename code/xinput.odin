package main
import win32 "core:sys/windows"

XUSER_MAX_COUNT::4

XINPUT_GAMEPAD_DPAD_UP         :: 0x0001
XINPUT_GAMEPAD_DPAD_DOWN       :: 0x0002
XINPUT_GAMEPAD_DPAD_LEFT       :: 0x0004
XINPUT_GAMEPAD_DPAD_RIGHT      :: 0x0008
XINPUT_GAMEPAD_START           :: 0x0010
XINPUT_GAMEPAD_BACK            :: 0x0020
XINPUT_GAMEPAD_LEFT_THUMB      :: 0x0040
XINPUT_GAMEPAD_RIGHT_THUMB     :: 0x0080
XINPUT_GAMEPAD_LEFT_SHOULDER   :: 0x0100
XINPUT_GAMEPAD_RIGHT_SHOULDER  :: 0x0200
XINPUT_GAMEPAD_A               :: 0x1000
XINPUT_GAMEPAD_B               :: 0x2000
XINPUT_GAMEPAD_X               :: 0x4000
XINPUT_GAMEPAD_Y               :: 0x8000

XINPUT_GAMEPAD_LEFT_THUMB_DEADZONE  :: 7849
XINPUT_GAMEPAD_RIGHT_THUMB_DEADZONE :: 8689
XINPUT_GAMEPAD_TRIGGER_THRESHOLD    :: 30

XINPUT_GAMEPAD::struct {
	wButtons:win32.WORD,
	bLeftTrigger:win32.BYTE,
	bRightTrigger:win32.BYTE,
	sThumbLX:win32.SHORT,
	sThumbLY:win32.SHORT,
	sThumbRX:win32.SHORT,
	sThumbRY:win32.SHORT,
}

XINPUT_STATE::struct {
  dwPacketNumber:win32.DWORD,
  Gamepad:XINPUT_GAMEPAD,
}

XINPUT_VIBRATION::struct {
	wLeftMotorSpeed:win32.WORD,
	wRightMotorSpeed:win32.WORD,
}

foreign import xinput "system:xinput.lib"

foreign xinput{
	XInputGetState::proc(dwUserIndex:win32.DWORD, pState:^XINPUT_STATE )->win32.DWORD ---
	XInputSetState::proc(dwUserIndex:win32.DWORD, pVibration:^XINPUT_VIBRATION)->win32.DWORD ---
}

