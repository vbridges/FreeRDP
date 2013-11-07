/**
 * FreeRDP: A Remote Desktop Protocol Implementation
 * Audio Output Virtual Channel
 *
 * Copyright 2013 Dell Software <Mike.McDonald@software.dell.com>
 * Copyright 2013 Corey Clayton <can.of.tuna@gmail.com>
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#include <pthread.h>

#include <winpr/wtypes.h>
#include <winpr/collections.h>
#include <winpr/sysinfo.h>

#include <freerdp/types.h>
#include <freerdp/codec/dsp.h>
#include <freerdp/utils/svc_plugin.h>

#import <AudioToolbox/AudioToolbox.h>

#include "rdpsnd_main.h"
#include "TPCircularBuffer.h"

#define INPUT_BUFFER_SIZE       32768//1048576
#define CIRCULAR_BUFFER_SIZE    (INPUT_BUFFER_SIZE * 4)

int bytesPerFrame;
int frameCnt;
wQueue* waveQ;

typedef struct wave_item
{
	UINT16 remoteTimeStampA;
	UINT16 localTimeStampA;
	BYTE ID;
	int numFrames;
	
} waveItem;

typedef struct rdpsnd_ios_plugin
{
	rdpsndDevicePlugin device;
	AudioComponentInstance audio_unit;
	TPCircularBuffer buffer;
	//pthread_mutex_t bMutex;
	pthread_mutex_t playMutex;
	BOOL is_opened;
	BOOL is_playing;
} rdpsndIOSPlugin;

#define THIS(__ptr) ((rdpsndIOSPlugin*)__ptr)

BOOL rdpsnd_isPlaying(rdpsndIOSPlugin* p)
{
	BOOL result = FALSE;
	
	pthread_mutex_lock(&p->playMutex);
	if (p->is_playing)
	{
		result = TRUE;
	}
	pthread_mutex_unlock(&p->playMutex);
	
	return result;
	
}

void rdpsnd_set_isPlaying(rdpsndIOSPlugin* p, BOOL b)
{
	pthread_mutex_lock(&p->playMutex);
	if (b == TRUE)
	{
		p->is_playing = 1;
	}
	else
	{
		p->is_playing = 0;
	}
	pthread_mutex_unlock(&p->playMutex);
}

static OSStatus rdpsnd_ios_monitor_cb(
				      void *inRefCon,
				      AudioUnitRenderActionFlags *ioActionFlags,
				      const AudioTimeStamp *inTimeStamp,
				      UInt32 inBusNumber,
				      UInt32 inNumberFrames,
				      AudioBufferList *ioData
				      )
{
	
	rdpsndIOSPlugin *p = THIS(inRefCon);
	
	//if ( *ioActionFlags == kAudioUnitRenderAction_PostRender )
	if ( *ioActionFlags == kAudioUnitRenderAction_PreRender )
	{
		int targetFrames;
		waveItem* peek;
		
		/*
		 printf("postRender Bus: %d inTimeStamp: %llu flags(%d) Frames: %d Buffers: %d\n",
		 (unsigned int)inBusNumber,
		 inTimeStamp->mHostTime,
		 (unsigned int)inTimeStamp->mFlags,
		 (unsigned int)inNumberFrames,
		 (unsigned int)ioData->mNumberBuffers);
		 */
		
		
		frameCnt += inNumberFrames;
		
		peek = Queue_Peek(waveQ);
		if (!peek)
		{
			printf("empty waveQ!\n");
			return noErr;
		}
		
		
		targetFrames = peek->numFrames;
		
		if (frameCnt >= targetFrames)
		{
			UINT16 tB;
			UINT16 diff;
			
			tB = (UINT16)GetTickCount();
			diff = tB - peek->localTimeStampA;
			
			/*printf("\tSend Confirm for %02X with timeStamp diff %d\n"
			 , peek->ID,
			 diff);*/
			frameCnt = frameCnt - peek->numFrames;
			
			peek = Queue_Dequeue(waveQ);
			
			rdpsnd_send_wave_confirm_pdu(p->device.rdpsnd, peek->remoteTimeStampA + diff, peek->ID);
			//printf("confirm with latency:%d\n", diff);
			
			free(peek);
		}
		
	}
	
	return noErr;
}


//This callback is used to feed the AU buffers
static OSStatus rdpsnd_ios_render_cb(
				     void *inRefCon,
				     AudioUnitRenderActionFlags *ioActionFlags,
				     const AudioTimeStamp *inTimeStamp,
				     UInt32 inBusNumber,
				     UInt32 inNumberFrames,
				     AudioBufferList *ioData
				     )
{
	unsigned int i;
	
	if (inBusNumber != 0)
	{
		return noErr;
	}
	
	rdpsndIOSPlugin *p = THIS(inRefCon);
	
	//pthread_mutex_lock(&p->bMutex);
	for (i = 0; i < ioData->mNumberBuffers; i++)
	{
		AudioBuffer* target_buffer = &ioData->mBuffers[i];
		
		int32_t available_bytes = 0;
		const void *buffer = TPCircularBufferTail(&p->buffer, &available_bytes);
		if (buffer != NULL && available_bytes > 0)
		{
			const int bytes_to_copy = MIN((int32_t)target_buffer->mDataByteSize, available_bytes);
			
			memcpy(target_buffer->mData, buffer, bytes_to_copy);
			target_buffer->mDataByteSize = bytes_to_copy;
			
			TPCircularBufferConsume(&p->buffer, bytes_to_copy);
		}
		else
		{
			target_buffer->mDataByteSize = 0;
			AudioOutputUnitStop(p->audio_unit);
			//p->is_playing = 0;
			rdpsnd_set_isPlaying(p, FALSE);
			
			printf("Buffer is empty (uderrun)\n");
		}
	}
	//pthread_mutex_unlock(&p->bMutex);
	
	return noErr;
}

static BOOL rdpsnd_ios_format_supported(rdpsndDevicePlugin* __unused device, AUDIO_FORMAT* format)
{
	if (format->wFormatTag == WAVE_FORMAT_PCM)
	{
		return 1;
	}
	return 0;
}

static void rdpsnd_ios_set_format(rdpsndDevicePlugin* __unused device, AUDIO_FORMAT* __unused format, int __unused latency)
{
}

static void rdpsnd_ios_set_volume(rdpsndDevicePlugin* __unused device, UINT32 __unused value)
{
}

static void rdpsnd_ios_start(rdpsndDevicePlugin* device)
{
	rdpsndIOSPlugin *p = THIS(device);
	
	/* If this device is not playing... */
	//if (!p->is_playing)
	if ( rdpsnd_isPlaying(p) == FALSE )
	{
		/* Start the device. */
		int32_t available_bytes = 0;
		//pthread_mutex_lock(&p->bMutex);
		TPCircularBufferTail(&p->buffer, &available_bytes);
		//pthread_mutex_unlock(&p->bMutex);
		
		if (available_bytes > 0)
		{
			//p->is_playing = 1;
			rdpsnd_set_isPlaying(p, TRUE);
			AudioOutputUnitStart(p->audio_unit);
		}
		else
		{
			printf("[!!!] start: availably bytes = %d\n", available_bytes);
		}
	}
	else
	{
		//printf("[!!!] Start called while playing!\n");
	}
}

static void rdpsnd_ios_stop(rdpsndDevicePlugin* __unused device)
{
	rdpsndIOSPlugin *p = THIS(device);
	
	/* If the device is playing... */
	//if (p->is_playing)
	if (rdpsnd_isPlaying(p) == TRUE)
	{
		/* Stop the device. */
		AudioOutputUnitStop(p->audio_unit);
		//p->is_playing = 0;
		rdpsnd_set_isPlaying(p, FALSE);
		
		/* Free all buffers. */
		//pthread_mutex_lock(&p->bMutex);
		TPCircularBufferClear(&p->buffer);
		//pthread_mutex_unlock(&p->bMutex);
	}
}

/*static void rdpsnd_ios_play(rdpsndDevicePlugin* device, BYTE* data, int size)
 {
 rdpsndIOSPlugin *p = THIS(device);
 
 const BOOL ok = TPCircularBufferProduceBytes(&p->buffer, data, size);
 if (!ok)
 {
 return;
 }
 
 printf("play: %d (%d frames)\n", size, size/bytesPerFrame);
 
 
 rdpsnd_ios_start(device);
 }*/


static void rdpsnd_ios_wave_play(rdpsndDevicePlugin* device, RDPSND_WAVE* wave)
{
	BYTE* data;
	int size;
	waveItem* wi;
	
	rdpsndIOSPlugin *p = THIS(device);
	
	data = wave->data;
	size = wave->length;
	
	//pthread_mutex_lock(&p->bMutex);
	const BOOL ok = TPCircularBufferProduceBytes(&p->buffer, data, size);
	//pthread_mutex_unlock(&p->bMutex);
	if (!ok)
	{
		printf("[!!!] Failed to produce bytes from buffer!\n");
		return;
	}
	
	//printf("play: %d (%d frames)\n", size, size/bytesPerFrame);
	
	wi = malloc(sizeof(waveItem));
	wi->ID = wave->cBlockNo;
	wi->localTimeStampA = wave->wLocalTimeA;
	wi->remoteTimeStampA = wave->wTimeStampA;
	wi->numFrames = size/bytesPerFrame;
	
	/*printf("Enqueue: waveItem[id:%02X localA:%d remoteA:%d frames:%d]\n",
	 wi->ID,
	 wi->localTimeStampA,
	 wi->remoteTimeStampA,
	 wi->numFrames);*/
	
	Queue_Enqueue(waveQ, wi);
	
	
	rdpsnd_ios_start(device);
}


static void rdpsnd_ios_open(rdpsndDevicePlugin* device, AUDIO_FORMAT* format, int __unused latency)
{
	rdpsndIOSPlugin *p = THIS(device);
	
	if (p->is_opened)
	{
		return;
	}
	
	/* Find the output audio unit. */
	AudioComponentDescription desc;
	desc.componentManufacturer = kAudioUnitManufacturer_Apple;
	desc.componentType = kAudioUnitType_Output;
	desc.componentSubType = kAudioUnitSubType_RemoteIO;
	desc.componentFlags = 0;
	desc.componentFlagsMask = 0;
	
	AudioComponent audioComponent = AudioComponentFindNext(NULL, &desc);
	if (audioComponent == NULL) return;
	
	/* Open the audio unit. */
	OSStatus status = AudioComponentInstanceNew(audioComponent, &p->audio_unit);
	if (status != 0) return;
	
	/* Set the format for the AudioUnit. */
	AudioStreamBasicDescription audioFormat = {0};
	audioFormat.mSampleRate       = format->nSamplesPerSec;
	audioFormat.mFormatID         = kAudioFormatLinearPCM;
	audioFormat.mFormatFlags      = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
	audioFormat.mFramesPerPacket  = 1; /* imminent property of the Linear PCM */
	audioFormat.mChannelsPerFrame = format->nChannels;
	audioFormat.mBitsPerChannel   = format->wBitsPerSample;
	audioFormat.mBytesPerFrame    = (format->wBitsPerSample * format->nChannels) / 8;
	audioFormat.mBytesPerPacket   = audioFormat.mBytesPerFrame * audioFormat.mFramesPerPacket;
	
	bytesPerFrame = audioFormat.mBytesPerFrame;
	
	status = AudioUnitSetProperty(
				      p->audio_unit,
				      kAudioUnitProperty_StreamFormat,
				      kAudioUnitScope_Input,
				      0,
				      &audioFormat,
				      sizeof(audioFormat));
	if (status != 0)
	{
		AudioComponentInstanceDispose(p->audio_unit);
		p->audio_unit = NULL;
		return;
	}
	
	/* Set up the AudioUnit callback. */
	
	AURenderCallbackStruct callbackStruct = {0};
	callbackStruct.inputProc = rdpsnd_ios_render_cb;
	callbackStruct.inputProcRefCon = p;
	status = AudioUnitSetProperty(
				      p->audio_unit,
				      kAudioUnitProperty_SetRenderCallback,
				      kAudioUnitScope_Input,
				      0,
				      &callbackStruct,
				      sizeof(callbackStruct));
	if (status != 0)
	{
		AudioComponentInstanceDispose(p->audio_unit);
		p->audio_unit = NULL;
		return;
	}
	
	//monitor callback
	status = AudioUnitAddRenderNotify(p->audio_unit, rdpsnd_ios_monitor_cb, p);
	if (status != 0)
	{
		printf("Could not register fake callback!\n");
		AudioComponentInstanceDispose(p->audio_unit);
		p->audio_unit = NULL;
		return;
	}
	
	
	/* Initialize the AudioUnit. */
	status = AudioUnitInitialize(p->audio_unit);
	if (status != 0)
	{
		AudioComponentInstanceDispose(p->audio_unit);
		p->audio_unit = NULL;
		return;
	}
	
	/* Allocate the circular buffer. */
	const BOOL ok = TPCircularBufferInit(&p->buffer, CIRCULAR_BUFFER_SIZE);
	if (!ok)
	{
		AudioUnitUninitialize(p->audio_unit);
		AudioComponentInstanceDispose(p->audio_unit);
		p->audio_unit = NULL;
		return;
	}
	
	p->is_opened = 1;
	
	//pthread_mutex_init(&p->bMutex, NULL);
	pthread_mutex_init(&p->playMutex, NULL);
	
	frameCnt = 0;
	waveQ = Queue_New(TRUE, 32, 2);
}

static void rdpsnd_ios_close(rdpsndDevicePlugin* device)
{
	rdpsndIOSPlugin *p = THIS(device);
	
	/* Make sure the device is stopped. */
	rdpsnd_ios_stop(device);
	
	/* If the device is open... */
	if (p->is_opened)
	{
		/* Close the device. */
		AudioUnitUninitialize(p->audio_unit);
		AudioComponentInstanceDispose(p->audio_unit);
		p->audio_unit = NULL;
		p->is_opened = 0;
		
		/* Destroy the circular buffer. */
		TPCircularBufferCleanup(&p->buffer);
	}
}

static void rdpsnd_ios_free(rdpsndDevicePlugin* device)
{
	rdpsndIOSPlugin *p = THIS(device);
	
	/* Ensure the device is closed. */
	rdpsnd_ios_close(device);
	
	/* Free memory associated with the device. */
	free(p);
}

#ifdef STATIC_CHANNELS
#define freerdp_rdpsnd_client_subsystem_entry	ios_freerdp_rdpsnd_client_subsystem_entry
#endif

int freerdp_rdpsnd_client_subsystem_entry(PFREERDP_RDPSND_DEVICE_ENTRY_POINTS pEntryPoints)
{
	rdpsndIOSPlugin *p = (rdpsndIOSPlugin*)malloc(sizeof(rdpsndIOSPlugin));
	memset(p, 0, sizeof(rdpsndIOSPlugin));
	
	p->device.Open = rdpsnd_ios_open;
	p->device.FormatSupported = rdpsnd_ios_format_supported;
	p->device.SetFormat = rdpsnd_ios_set_format;
	p->device.SetVolume = rdpsnd_ios_set_volume;
	//p->device.Play = rdpsnd_ios_play;
	p->device.Start = rdpsnd_ios_start;
	p->device.Close = rdpsnd_ios_close;
	p->device.Free = rdpsnd_ios_free;
	p->device.WavePlay = rdpsnd_ios_wave_play;
	
	pEntryPoints->pRegisterRdpsndDevice(pEntryPoints->rdpsnd, (rdpsndDevicePlugin*)p);
	
	return 0;
}