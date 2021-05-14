#ifndef BUFFERING_SOCKET_H
#define BUFFERING_SOCKET_H

#include "winsock.h"

#include <string>
#include <queue>
#include <mutex>
#include <fstream>

enum enumConnectionState
{
	DISCONNECTED,
	CONNECTED,
	STOPPED,
};

class BufferingSocket
{
public:
	BufferingSocket();
	~BufferingSocket();

	void disconnect();
	void stop();
	void createConnection(std::string *host, const int *port);
	void enqueueForSending(std::string *payload);
	auto dequeueFromReceiveQueue();

	int getAndResetReconnected();
	int getFlagConnected();

private:
	SOCKET tcpSocket;
	std::string *tcpHost;
	int tcpPort;

	int flagReconnected = 0;
	volatile enumConnectionState connectionState = DISCONNECTED;

	std::queue<std::string *> sendBuffer;
	std::deque<std::string *> sendQueue;
	std::deque<std::string *> receiveQueue;

	std::mutex sendMutexLock;
	std::mutex receiveMutexLock;

	void reconnect();
	void tcpConnect();
};

#endif