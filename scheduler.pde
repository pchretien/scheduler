//// scheduler ////
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License Version 2
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
//
// You will find the latest version of this code at the following address:
// http://github.com/pchretien
//
// You can contact me at the following email address:
// philippe.chretien at gmail.com


//////////////////////////////////////////////////////////////
// Scheduler
//////////////////////////////////////////////////////////////

#define QUEUE_MAX 32
#define SCHEDULE_MAX 32

#define INIT_TIMER_COUNT 6
#define RESET_TIMER2 TCNT2 = INIT_TIMER_COUNT

unsigned long __ulCounter = 0;
ISR(TIMER2_OVF_vect) {
  RESET_TIMER2;
  __ulCounter++;    
};

class ITask;
class Scheduler;

typedef struct ScheduleItemStruct
{
  ITask* task;
  unsigned long milliseconds;
} ScheduleItem;

class ITask
{
  public:
    virtual void setup() = 0;
    virtual void run(Scheduler* scheduler) = 0;    
};

class Scheduler
{
  public:
    Scheduler();
    void setup();
    void processMessages();
    
    void queue(ITask* task);
    void clearQueue();
    
    void schedule(ITask*, int); 
    void clearSchedule();
 
  private:
    ITask* _taskQueue[QUEUE_MAX];
    ScheduleItem _taskSchedule[SCHEDULE_MAX];
};

Scheduler::Scheduler()
{
  clearQueue();
  clearSchedule();
}

void Scheduler::setup()
{
  //Timer2 Settings: Timer Prescaler /64,
  TCCR2A |= (1<<CS22);
  TCCR2A &= ~((1<<CS21) | (1<<CS20));

  // Use normal mode
  TCCR2A &= ~((1<<WGM21) | (1<<WGM20));

  // Use internal clock - external clock not used in Arduino
  ASSR |= (0<<AS2);

  //Timer2 Overflow Interrupt Enable
  TIMSK2 |= (1<<TOIE2) | (0<<OCIE2A);

  // Reset timer
  RESET_TIMER2;
  sei();
}

void Scheduler::processMessages()
{
  // Check the schedule
  for( int i=0; i<SCHEDULE_MAX; i++)
  {
    if(_taskSchedule[i].task && 
       _taskSchedule[i].milliseconds <= __ulCounter)
    {
      queue(_taskSchedule[i].task);
      _taskSchedule[i].task = 0;
    }
  }
  
  // Clear the queue
  for( int i=0; i<QUEUE_MAX; i++)
  {
    if(_taskQueue[i] )
    {
      _taskQueue[i]->run(this);
      _taskQueue[i] = 0;
    }
  }
}

void Scheduler::queue(ITask* task)
{  
  for( int i=0; i<QUEUE_MAX; i++)
  {
    if(!_taskQueue[i] )
    {
      _taskQueue[i] = task;
      return;
    }
  }
}

void Scheduler::clearQueue()
{
  for( int i=0; i<QUEUE_MAX; i++)
    _taskQueue[i] = 0;
}

void Scheduler::schedule(ITask* task, int milliseconds)
{
  for( int i=0; i<SCHEDULE_MAX; i++)
  {
    if(!_taskSchedule[i].task)
    {
      _taskSchedule[i].task = task;
      _taskSchedule[i].milliseconds = __ulCounter + milliseconds;
      return;
    }
  }
}

void Scheduler::clearSchedule()
{
  for( int i=0; i<SCHEDULE_MAX; i++)
    _taskSchedule[i].task = 0;
}

//////////////////////////////////////////////////////////////
// Task definition examples
//////////////////////////////////////////////////////////////

class Blinker : public ITask
{
  public:
    void setup();
    void run(Scheduler*);
    Blinker(int, int);
    
  private:
    int _pin;
    int _period;
    int _state;
};

Blinker::Blinker(int pin, int period)
{
  _pin = pin;
  _state = 0;
  _period = period;
}

void Blinker::setup()
{
  pinMode( _pin, OUTPUT);  
}

void Blinker::run(Scheduler* scheduler)
{
  scheduler->schedule(this, _period);
  
  _state = (_state>0)?0:1;  
  digitalWrite(_pin, _state);
}

#include <Servo.h>
class ServoTask : public ITask
{
  public:
    void setup();
    void run(Scheduler*);
    ServoTask(int, int);
    
  private:
    int _pin;
    int _index;
    int _period;
    int _angle[2];
    Servo servo;
};

ServoTask::ServoTask(int pin, int period)
{
  _pin = pin;
  _index = 0;
  _period = period;
  _angle[0] = 45;
  _angle[1] = 135;
}

void ServoTask::setup()
{
  servo.attach(_pin);
}

void ServoTask::run(Scheduler* scheduler)
{
  scheduler->schedule(this, _period);
  
  _index = (_index)?0:1;
  servo.write(_angle[_index]);
}

class Clock : public ITask
{
  public:
    void setup();
    void run(Scheduler*);
    Clock();
    
  private:
    int _seconds;
};

Clock::Clock()
{
  _seconds = 0;
}

void Clock::setup()
{
  Serial.begin(115200);
}

void Clock::run(Scheduler* scheduler)
{
  scheduler->schedule(this, 1000);  
  Serial.println(_seconds++);
}

//////////////////////////////////////////////////////////////
// MAIN
//////////////////////////////////////////////////////////////

// Create a task scheduler singleton
Scheduler __scheduler;

// Create custom tasks
Clock _clock;
Blinker _blinker12(12, 1000);
Blinker _blinker13(13, 50);
ServoTask _servo10(10, 500);
ServoTask _servo11(11, 3000);

void setup()
{ 
  _clock.setup();
  _servo10.setup();
  _servo11.setup();
  _blinker12.setup();  
  _blinker13.setup();  
    
  __scheduler.setup();
  __scheduler.queue(&_clock);
  __scheduler.queue(&_blinker12);
  __scheduler.queue(&_blinker13);
  __scheduler.schedule(&_servo10, 1000);
  __scheduler.schedule(&_servo11, 2000);
}

void loop()
{
  __scheduler.processMessages();
}

