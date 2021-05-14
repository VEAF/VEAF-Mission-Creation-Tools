#include "BufferingSocket.h"

/**
 * This object is a buffered socket.
 * It will accept data, store it in a queue, and send it to a server via a tcp socket, from a separate thread, when able.
 * We call it from a DCS hook, using a lua wrapper (LuaWrapper) to avoid blocking the main game thread.
 * This code comes from Perun (https://github.com/szporwolik/perun) with some modifications.
 */

BufferingSocket::BufferingSocket()
{
    tcpSocket = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
}

BufferingSocket::~BufferingSocket()
{
}

int BufferingSocket::getAndResetReconnected()
{
    int result = this->flagReconnected;

    this->flagReconnected = 0;

    return result;
}

int BufferingSocket::getFlagConnected()
{
    return this->connectionState;
}

void BufferingSocket::tcpConnect()
{
    // Create socket address object from TCP port and host
    SOCKADDR_IN socketAddress;
    socketAddress.sin_family = AF_INET;
    socketAddress.sin_port = htons(u_short(this->tcpPort));
    socketAddress.sin_addr.s_addr = *((unsigned long *)gethostbyname(this->tcpHost->c_str())->h_addr);

    if (connect(tcpSocket, (sockaddr *)&socketAddress, sizeof(SOCKADDR_IN)) == 0)
    {
        this->connectionState = CONNECTED;
        this->flagReconnected = 1;
    }
}

void BufferingSocket::createConnection(std::string *host, const int *port)
{
    // TCP connection - ConnectTo
    this->tcpHost = host;
    this->tcpPort = *port;

    tcpConnect();

    // Create new thread for sending the data in the send queue
    std::thread senderThread([this]() {
        // TCP sending loop
        bool nothingToSend = false;
        while (connectionState != STOPPED)
        {
            // Endless loop (will run after main dll thread is active)
            if (connectionState == CONNECTED && sendMutexLock.try_lock())
            {
                if (sendQueue.empty())
                {
                    nothingToSend = true;
                }
                else
                {
                    // Payload in queue
                    auto payload = sendQueue.front();
                    int length = payload->length();
                    int bytesSent = send(tcpSocket, payload->c_str(), payload->length(), 0);

                    if (bytesSent == payload->length())
                    {
                        // All payload was sent
                        sendQueue.pop_front();
                        delete payload;
                    }
                    else
                    {
                        // Remaining paylad
                        if (bytesSent > 0)
                        {
                            // Send remaining bytes
                            auto shortened = payload->substr(bytesSent, length - bytesSent);
                            sendQueue.pop_front();
                            sendQueue.push_front(&shortened);
                            delete payload;
                        }
                        else
                        {
                            // Payload was not sent - handle error
                            switch (WSAGetLastError())
                            {
                            // Connection was reset
                            case WSAECONNRESET:
                            // Connection aborted
                            case WSAECONNABORTED:
                            // Connection was closed
                            case WSAESHUTDOWN:
                                connectionState = DISCONNECTED;
                                reconnect();
                            }
                        }
                    }
                }
                sendMutexLock.unlock();
            }
            else
            {
                // Not connected
                reconnect();
            }
            // sleep longer if nothing to send
            if (nothingToSend)
            {
                Sleep(100);
            }
            else
            {
                Sleep(10);
            }
        }
    });
    senderThread.detach(); // Detach TCP thread from main thread

    // Create new thread for listening and storing the received data in the receive queue
    std::thread receiverThread([this]() {
        // TCP sending loop
        while (connectionState != STOPPED)
        {
            // Endless loop (will run after main dll thread is active)
            if (connectionState == CONNECTED && receiveMutexLock.try_lock())
            {
                // Receive from the socket
                std::vector<char> buffer(5000);
                int bytes = recv(tcpSocket, buffer.data(), buffer.size(), 0);

                // Store what's been received
                receiveQueue.push_back(buffer.());

                if (bytesSent == payload->length())
                {
                    // All payload was sent
                    sendQueue.pop_front();
                    delete payload;
                }
                else
                {
                    // Remaining paylad
                    if (bytesSent > 0)
                    {
                        // Send remaining bytes
                        auto shortened = payload->substr(bytesSent, length - bytesSent);
                        sendQueue.pop_front();
                        sendQueue.push_front(&shortened);
                        delete payload;
                    }
                    else
                    {
                        // Payload was not sent - handle error
                        switch (WSAGetLastError())
                        {
                        // Connection was reset
                        case WSAECONNRESET:
                        // Connection aborted
                        case WSAECONNABORTED:
                        // Connection was closed
                        case WSAESHUTDOWN:
                            connectionState = DISCONNECTED;
                            reconnect();
                        }
                    }
                }
                receiveMutexLock.unlock();
            }
            else if (connectionState != CONNECTED) 
            {
                // Not connected
                reconnect();
            }
            Sleep(100);
        }
    });
    receiverThread.detach(); // Detach TCP thread from main thread}
}

void BufferingSocket::reconnect()
{
    if (connectionState == DISCONNECTED)
    {
        disconnect();
        tcpSocket = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP); // Reset socket
    }

    tcpConnect();
}

void BufferingSocket::disconnect()
{
    // TCP connection - Disconnect
    closesocket(tcpSocket);
    connectionState = DISCONNECTED;
}

void BufferingSocket::stop()
{
    disconnect();
    connectionState = STOPPED;
}

void BufferingSocket::enqueueForSending(std::string *payload)
{
    if (sendMutexLock.try_lock())
    {
        while (!sendBuffer.empty())
        {
            // Shift buffer to queue
            sendQueue.push_back(sendBuffer.front());
            sendBuffer.pop();
        }
        sendQueue.push_back(payload);
        sendMutexLock.unlock();
    }
    else
    {
        sendBuffer.push(payload);
    }
}

auto BufferingSocket::dequeueFromReceiveQueue()
{
    if (receiveMutexLock.try_lock())
    {
        // return receive queue first element
        auto result = receiveQueue.front();
        receiveQueue.pop_front();
        return result;
        receiveMutexLock.unlock();
    }
    else
    {
        return NULL;
    }
}