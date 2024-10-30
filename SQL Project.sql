CREATE DATABASE Hotel
use Hotel


CREATE TABLE Hotel (
    HID int IDENTITY PRIMARY KEY,
    HName NVARCHAR(100) NOT NULL UNIQUE,
    HLocation NVARCHAR(100) NOT NULL,
    Hphone NVARCHAR(20) NOT NULL,
    Rating DECIMAL(2,1)
	CONSTRAINT chk_rating CHECK (Rating BETWEEN 1 AND 5)    
)

--indexes to Hotel table:
CREATE NONCLUSTERED INDEX idx_Hotel_HName ON Hotel (HName)
CREATE NONCLUSTERED INDEX idx_Hotel_Rating ON Hotel (Rating)


CREATE TABLE Rooms (
    RID int IDENTITY PRIMARY KEY,
    RNum NVARCHAR(10) NOT NULL UNIQUE,
	HID int NOT NULL,
    RType NVARCHAR(20) CHECK (RType IN ('Single', 'Double', 'Suite')),
    Price DECIMAL(10, 2) CHECK (Price > 0),
    Rstatus BIT DEFAULT 1,
    FOREIGN KEY (HID) REFERENCES Hotel(HID)
	   ON DELETE CASCADE ON UPDATE CASCADE,
    UNIQUE (HID, RNum)
)
--Use a Composite Unique Constraint:


ALTER TABLE Rooms
ADD CONSTRAINT UQ_Rooms_HID_RNum UNIQUE (HID, RNum);

CREATE CLUSTERED INDEX idx_Rooms_HID_RNum ON Rooms (HID, RNum)
CREATE NONCLUSTERED INDEX idx_Rooms_RType ON Rooms (RType)




CREATE TABLE Guests (
    GID int IDENTITY PRIMARY KEY,
    GName NVARCHAR(100),
    Gphone NVARCHAR(20),
    IDProof NVARCHAR(50) NOT NULL,
    --IDProofNumber NVARCHAR(50) NOT NULL,
    GEmail NVARCHAR(100) NOT NULL UNIQUE
)

ALTER TABLE Guests
DROP COLUMN IDProofNumber

ALTER TABLE Guests
ADD IDProofNumber NVARCHAR(50) NOT NULL







CREATE TABLE Bookings (
    BID int IDENTITY PRIMARY KEY,
    BDate DATE NOT NULL,
    GID int NOT NULL,
    RID int NOT NULL,
    CheckIn DATE NOT NULL,
    CheckOut DATE NOT NULL,
    BStatus NVARCHAR(20) DEFAULT 'Pending' CHECK (BStatus IN ('Pending', 'Confirmed', 'Canceled', 'Check-in', 'Check-out')),
    TotalCost DECIMAL(10, 2),
    FOREIGN KEY (GID) REFERENCES Guests(GID) 
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (RID) REFERENCES Rooms(RID) 
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT chk_CheckIn_CheckOut CHECK (CheckIn <= CheckOut) -- This constraint checks the condition
)

--indexes to Bookings table:
CREATE NONCLUSTERED INDEX idx_Bookings_GID ON Bookings (GID)
CREATE NONCLUSTERED INDEX idx_Bookings_BStatus ON Bookings (BStatus)
CREATE NONCLUSTERED INDEX idx_Bookings_RID_CheckIn_CheckOut ON Bookings (RID, CheckIn, CheckOut)


CREATE TABLE Payments (
    PID int IDENTITY PRIMARY KEY,
    PDate DATE NOT NULL,
	BID int NOT NULL,
    Amount DECIMAL(10, 2) NOT NULL CHECK (Amount > 0),
    Method NVARCHAR(50),
    FOREIGN KEY (BID) REFERENCES Bookings(BID) 
    ON DELETE CASCADE ON UPDATE CASCADE   
)


CREATE TABLE Staff (
    StID int IDENTITY PRIMARY KEY,
    StName NVARCHAR(100),
	HID int NOT NULL,
    StPosition NVARCHAR(50),
    Stphone NVARCHAR(20),
    FOREIGN KEY (HID) REFERENCES Hotel(HID) 
    ON DELETE CASCADE ON UPDATE CASCADE    
)


CREATE TABLE Reviews (
    RID int IDENTITY PRIMARY KEY,
    HID int NOT NULL,
    GID int NOT NULL,
    RVDate DATE NOT NULL,
    RVRating INT CHECK (RVRating BETWEEN 1 and 5),
    Comments NVARCHAR(255) DEFAULT 'No comments',
    FOREIGN KEY (HID) REFERENCES Hotel(HID) 
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (GID) REFERENCES Guests(GID) 
        ON DELETE CASCADE ON UPDATE CASCADE 
        
)

--Views:
--View1:
CREATE VIEW VTopRatedHotels AS
select 
    h.HName,
    h.Rating,
    COUNT(r.RID) AS TotalRooms,
    AVG(r.Price) AS AvgRoomPrice
FROM Hotel h
JOIN Rooms r ON h.HID = r.HID
where  h.Rating >= 4.5
	
 select TotalRooms,AvgRoomPrice from VTopRatedHotels
  select * from VTopRatedHotels

--View2:
CREATE VIEW VGuestBookings AS
select 
    G.GName,
    COUNT(B.BID) AS TotalBookings,
    COALESCE(SUM(P.Amount), 0) as TotalAmountSpent  --If no payments exist, COALESCE returns 0, preventing a NULL result when no payments are found.
FROM  Guests G
 JOIN Bookings B ON G.GID = B.GID
 JOIN Payments P ON B.BID = P.BID

select TotalBookings,TotalAmountSpent from VGuestBookings
select * from VGuestBookings

--View3:
alter VIEW VAvailableRooms as
select 
    H.HName,
    R.RType,
    R.Price,
    R.Rstatus as [available rooms]
FROM  Hotel H
JOIN  Rooms R ON H.HID = R.HID
WHERE  R.Rstatus = 1  -- Only available rooms
GROUP BY 
  R.RType
 SELECT *
FROM VAvailableRooms
ORDER BY  Price ASC
 
 --View4:
CREATE VIEW VBookingSummary AS
select 
    H.HName,
    COUNT(B.BID) AS TotalBookings,
    SUM(CASE WHEN B.BStatus = 'Confirmed' THEN 1 ELSE 0 END) AS ConfirmedBookings,
    SUM(CASE WHEN B.BStatus = 'Pending' THEN 1 ELSE 0 END) AS PendingBookings,
    SUM(CASE WHEN B.BStatus = 'Canceled' THEN 1 ELSE 0 END) AS CanceledBookings
FROM  Hotel H
JOIN Rooms R ON H.HID = R.HID
JOIN Bookings B ON R.RID = B.RID
GROUP BY 
  H.HName


select *
from VBookingSummary

 --View5:
 CREATE VIEW VPaymentHistory AS
select 
    G.GName AS GuestName,
    H.HName AS HotelName,
    B.BStatus AS BookingStatus,
    SUM(P.Amount) OVER(PARTITION BY B.BID, G.GID) AS TotalPaymentForBooking
FROM Payments P
JOIN  Bookings B ON P.BID = B.BID
JOIN Guests G ON B.GID = G.GID
JOIN Rooms R ON B.RID = R.RID
JOIN Hotel H ON R.HID = H.HID

select*
from VPaymentHistory

--Function 1:
CREATE FUNCTION GetAverageRating(@HotelID int)
RETURNS DECIMAL(3, 2)
as
BEGIN
    DECLARE @AverageRating DECIMAL

    select 
        @AverageRating = AVG(CAST(RVRating AS DECIMAL(3, 2)))   --CAST is used to ensure decimal precision in the calculation.
	FROM Reviews
    WHERE HID = @HotelID

    RETURN @AverageRating  --ISNULL returns 0 
END
select dbo.GetAverageRating(4) AS AverageRate


--Function 2:
CREATE FUNCTION GetNextAvailableRoom(@HotelID INT, @RoomType NVARCHAR(20))
RETURNS NVARCHAR(10)
AS
BEGIN
    DECLARE @NextAvailableRoom NVARCHAR(10)

    SELECT TOP 1    --Retrieves the top (first) room that matches the RNum
        @NextAvailableRoom = R.RNum
    FROM Rooms R
    WHERE 
        R.HID = @HotelID
        AND R.RType = @RoomType
        AND R.Rstatus = 1 -- Room is available
    RETURN @NextAvailableRoom
END

select dbo.GetNextAvailableRoom(1, 'Single') AS [Next Available Room]

--Function 3:
CREATE FUNCTION CalculateOccupancyRate(@HotelID int)
RETURNS DECIMAL(5, 2)
as
BEGIN
    DECLARE @TotalRooms int
    DECLARE @BookedRooms int
    DECLARE @OccupancyRate DECIMAL

    -- Get the total number of rooms for the hotel
    select @TotalRooms = COUNT(RID) FROM Rooms
    where HID = @HotelID

    -- Get the number of rooms booked in the last 30 days
    select @BookedRooms = COUNT(DISTINCT B.RID) FROM Bookings B
    JOIN Rooms R ON B.RID = R.RID
    where R.HID = @HotelID
      AND B.BStatus IN ('Confirmed', 'Check-in')  -- Only consider active bookings
      AND B.BDate >= DATEADD(DAY, -30, GETDATE())

    -- Calculate the occupancy rate
    if @TotalRooms > 0
        SET @OccupancyRate = (CAST(@BookedRooms AS DECIMAL(5, 2)) / @TotalRooms) * 100
    else
        SET @OccupancyRate = 0

    RETURN @OccupancyRate
END
select dbo.CalculateOccupancyRate(1) AS OccupancyRate


--Stored Procedure 1: 
CREATE PROCEDURE sp_MarkRoomUnavailable
    @BookingID int
as
BEGIN
    --  for Checking  if the  BStatus is confirmed:
    if EXISTS (SELECT 1 FROM Bookings WHERE BID = @BookingID and BStatus = 'Confirmed')
    BEGIN
        -- Update the room status to unavailable
        UPDATE Rooms
        SET Rstatus = 0 --  where 0 is unavailable
        where RID = (SELECT RID FROM Bookings where BID = @BookingID)
    END
    else
    BEGIN
        select  'Booking is not confirmed. Room status will not be updated.'
    END
END

EXEC sp_MarkRoomUnavailable @BookingID = 11


--Stored Procedure 2: 
CREATE PROCEDURE sp_UpdateBookingStatus
    @BookingID int,
    @NewStatus NVARCHAR(20) -- Accepts 'Check-in', 'Check-out', or 'Canceled' as valid status inputs
as
BEGIN
    DECLARE @CurrentDate DATE = GETDATE()
    DECLARE @CheckInDate DATE
    DECLARE @CheckOutDate DATE

    -- Retrieve the CheckIn and CheckOut dates for the booking
    select @CheckInDate = CheckIn, @CheckOutDate = CheckOut
    FROM Bookings
    where BID = @BookingID

    -- Check if booking exists
    IF @CheckInDate is null or @CheckOutDate is null
    BEGIN
        select 'Booking not found.' as Message
        RETURN
    END

    -- Update the booking status based on the provided @NewStatus
    if @NewStatus = 'Check-in' and @CurrentDate = @CheckInDate
    BEGIN
        UPDATE Bookings
        SET BStatus = 'Check-in'
        where BID = @BookingID
        select 'Booking status updated to Check-in.' as Message
    END
    else if @NewStatus = 'Check-out' and @CurrentDate = @CheckOutDate
    BEGIN
        UPDATE Bookings
        SET BStatus = 'Check-out'
        where BID = @BookingID
        select 'Booking status updated to Check-out.' as Message
    END
    else if @NewStatus = 'Canceled'
    BEGIN
        UPDATE Bookings
        SET BStatus = 'Canceled'
        WHERE BID = @BookingID;
        select 'Booking status updated to Canceled.' as Message
    END
    else
    BEGIN
        select 'Invalid status or date does not match booking details.' as Message
    END
END

EXEC sp_UpdateBookingStatus @BookingID = 1, @NewStatus = ' Check-in'


--Stored Procedure 3: 

CREATE PROCEDURE sp_RankGuestsBySpending
as
BEGIN
    SELECT 
        G.GID,
        G.GName as [Guest Name],
        SUM(P.Amount) as [Total Spending],
        RANK() OVER(ORDER BY SUM(P.Amount) DESC) as [Spending Rank]
    FROM Guests G
    JOIN 
        Bookings B ON G.GID = B.GID
    JOIN 
        Payments P ON B.BID = P.BID
    GROUP BY 
        G.GID, G.GName
    ORDER BY 
        [Spending Rank]
END

EXEC sp_RankGuestsBySpending

--Trigger 1: 
CREATE TRIGGER UpdateRoomAvailability
ON Bookings
AFTER INSERT
as
BEGIN
    -- Update the room's availability to 'Unavailable' (0) when a new booking is added
    UPDATE Rooms
    SET Rstatus = 0  -- 0 indicates 'Unavailable'
    where RID in (select RID FROM Inserted)
END



--Trigger 2:
Alter TRIGGER CalculateTotalRevenue
ON Payments
AFTER INSERT
AS
Select Sum(Amount) as Revenue
From Payments
Select *
From Payments
INSERT INTO Payments(BID, PDate, Amount, Method)
VALUES
(3, '2024-10-02', 250, 'Credit')





--Trigger 3: 
alter TRIGGER CheckInDateValidation
ON Bookings
INSTEAD OF INSERT
AS
BEGIN
    -- Check if any inserted rows have a check-in date later than the check-out date
    IF EXISTS (
        SELECT 1
        FROM inserted
        WHERE CheckIn> CheckOut
    )
    BEGIN
        SELECT 'Check-in date cannot be later than the check-out date.'
    END
    ELSE
    BEGIN
        INSERT INTO Bookings 
         SELECT 'Check-in date cannot be later than the check-out date.', 16, 1;
        FROM inserted
    END
END