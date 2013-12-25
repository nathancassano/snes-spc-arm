LOCAL_PATH := $(call my-dir)

NDK_MODULE_PATH := $(LOCAL_PATH)

include $(CLEAR_VARS)

LOCAL_MODULE_TAGS := user

LOCAL_ARM_MODE := arm

LOCAL_DEFAULT_CPP_EXTENSION := cpp

LOCAL_MODULE := snes_spc

LOCAL_PRELINK_MODULE := false

LOCAL_SRC_FILES := snes_spc/SNES_SPC.cpp snes_spc/SNES_SPC_misc.cpp snes_spc/SPC_DSP.cpp snes_spc/SNES_SPC_state.cpp snes_spc/spc700.S interface.cpp

LOCAL_CFLAGS := -Xassembler --alternate -Xassembler -I. 

include $(BUILD_SHARED_LIBRARY)
