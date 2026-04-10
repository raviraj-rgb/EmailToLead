List<EmailToLead_Ai__Custom_Exception__c> records = new List<EmailToLead_Ai__Custom_Exception__c>();

// Record 1 - Free-form business inquiry
records.add(new EmailToLead_Ai__Custom_Exception__c(
    Name = 'Test Retry 1',
    EmailToLead_Ai__Retry_Status__c = 'Pending',
    EmailToLead_Ai__Retry_Count__c = 0,
    EmailToLead_Ai__Next_Retry_Time__c = System.now().addMinutes(-10),
    EmailToLead_Ai__Email_Header__c = 'From: john.smith@acmecorp.com\nTo: sales@company.com\nSubject: Interested in your shade products\n\nHi,\n\nMy name is John Smith and I am the Procurement Manager at Acme Corporation. We are looking for commercial shade structures for our new office campus in Austin, TX 78701.\n\nOur budget is approximately $50,000 and we need coverage for about 2000 sq ft of outdoor seating area.\n\nPlease contact me at john.smith@acmecorp.com or call 512-555-1234.',
    EmailToLead_Ai__Email_Body__c = 'Shade products inquiry from Acme Corp',
    EmailToLead_Ai__Class_Name__c = 'EmailToLeadService',
    EmailToLead_Ai__Type__c = 'Exception',
    EmailToLead_Ai__Exception_message__c = 'Callout timeout during initial processing'
));

// Record 2 - School inquiry
records.add(new EmailToLead_Ai__Custom_Exception__c(
    Name = 'Test Retry 2',
    EmailToLead_Ai__Retry_Status__c = 'Pending',
    EmailToLead_Ai__Retry_Count__c = 0,
    EmailToLead_Ai__Next_Retry_Time__c = System.now().addMinutes(-10),
    EmailToLead_Ai__Email_Header__c = 'From: maria.garcia@brightstarschools.org\nTo: sales@company.com\nSubject: Playground shade for elementary school\n\nHello,\n\nI am Maria Garcia, the Principal at Bright Star Elementary School located at 456 Oak Avenue, San Diego, CA 92101. We need shade structures for our playground area to protect children from the sun.\n\nWe have a budget of $25,000 and would like to schedule a site visit. My phone number is 619-555-8765 and email is maria.garcia@brightstarschools.org.',
    EmailToLead_Ai__Email_Body__c = 'Playground shade request from school',
    EmailToLead_Ai__Class_Name__c = 'EmailToLeadService',
    EmailToLead_Ai__Type__c = 'Exception',
    EmailToLead_Ai__Exception_message__c = 'API rate limit exceeded'
));

// Record 3 - Corporate inquiry
records.add(new EmailToLead_Ai__Custom_Exception__c(
    Name = 'Test Retry 3',
    EmailToLead_Ai__Retry_Status__c = 'Pending',
    EmailToLead_Ai__Retry_Count__c = 0,
    EmailToLead_Ai__Next_Retry_Time__c = System.now().addMinutes(-10),
    EmailToLead_Ai__Email_Header__c = 'From: robert.chen@globaltech.io\nTo: sales@company.com\nSubject: Outdoor canopy solutions\n\nDear Sales Team,\n\nI am Robert Chen, VP of Facilities at GlobalTech Solutions. Our company at 789 Innovation Drive, Seattle, WA 98101 is expanding and we need outdoor canopy solutions for our employee break areas.\n\nWe have approximately 150 employees and need coverage for a 3000 sq ft patio area. Our budget range is $75,000-$100,000.\n\nPlease send me a quote at robert.chen@globaltech.io or reach me at 206-555-4321.',
    EmailToLead_Ai__Email_Body__c = 'Canopy solutions inquiry',
    EmailToLead_Ai__Class_Name__c = 'EmailToLeadService',
    EmailToLead_Ai__Type__c = 'Exception',
    EmailToLead_Ai__Exception_message__c = 'Connection reset during callout'
));

// Record 4 - Church inquiry
records.add(new EmailToLead_Ai__Custom_Exception__c(
    Name = 'Test Retry 4',
    EmailToLead_Ai__Retry_Status__c = 'Pending',
    EmailToLead_Ai__Retry_Count__c = 0,
    EmailToLead_Ai__Next_Retry_Time__c = System.now().addMinutes(-10),
    EmailToLead_Ai__Email_Header__c = 'From: pastor.williams@gracechurch.org\nTo: sales@company.com\nSubject: Shade for church parking lot\n\nHello,\n\nI am Pastor David Williams from Grace Community Church at 321 Faith Street, Phoenix, AZ 85001. We are looking for shade structures to cover our parking lot for our congregation during summer months.\n\nWe need coverage for approximately 50 parking spaces. Our budget is $35,000.\n\nPlease contact me at pastor.williams@gracechurch.org or 602-555-9876.',
    EmailToLead_Ai__Email_Body__c = 'Church parking shade request',
    EmailToLead_Ai__Class_Name__c = 'EmailToLeadService',
    EmailToLead_Ai__Type__c = 'Exception',
    EmailToLead_Ai__Exception_message__c = 'JSON parse error in AI response'
));

// Record 5 - Restaurant chain
records.add(new EmailToLead_Ai__Custom_Exception__c(
    Name = 'Test Retry 5',
    EmailToLead_Ai__Retry_Status__c = 'Pending',
    EmailToLead_Ai__Retry_Count__c = 0,
    EmailToLead_Ai__Next_Retry_Time__c = System.now().addMinutes(-10),
    EmailToLead_Ai__Email_Header__c = 'From: sarah.johnson@bistrogroup.com\nTo: sales@company.com\nSubject: Patio shade for restaurant chain\n\nHi there,\n\nMy name is Sarah Johnson, Operations Director at The Bistro Group. We operate 5 restaurants across Houston, TX and need patio shade solutions for all locations.\n\nOur main office is at 555 Culinary Blvd, Houston, TX 77001. Each location needs approximately 500 sq ft of coverage. Total budget is $120,000.\n\nEmail: sarah.johnson@bistrogroup.com\nPhone: 713-555-2468',
    EmailToLead_Ai__Email_Body__c = 'Restaurant patio shade inquiry',
    EmailToLead_Ai__Class_Name__c = 'EmailToLeadService',
    EmailToLead_Ai__Type__c = 'Exception',
    EmailToLead_Ai__Exception_message__c = 'Timeout waiting for AI response'
));

// Record 6 - Childcare center
records.add(new EmailToLead_Ai__Custom_Exception__c(
    Name = 'Test Retry 6',
    EmailToLead_Ai__Retry_Status__c = 'Pending',
    EmailToLead_Ai__Retry_Count__c = 0,
    EmailToLead_Ai__Next_Retry_Time__c = System.now().addMinutes(-10),
    EmailToLead_Ai__Email_Header__c = 'From: linda.martinez@sunshinecare.com\nTo: sales@company.com\nSubject: Shade for outdoor play area\n\nHello,\n\nI am Linda Martinez, Director at Sunshine Childcare Center located at 900 Rainbow Lane, Denver, CO 80201. We need shade structures for our outdoor play area to meet state childcare regulations.\n\nThe play area is 1500 sq ft and we need full coverage. Budget is $20,000.\n\nContact: linda.martinez@sunshinecare.com, 303-555-7654',
    EmailToLead_Ai__Email_Body__c = 'Childcare shade requirement',
    EmailToLead_Ai__Class_Name__c = 'EmailToLeadService',
    EmailToLead_Ai__Type__c = 'Exception',
    EmailToLead_Ai__Exception_message__c = 'HTTP 503 Service Unavailable'
));

// Record 7 - University
records.add(new EmailToLead_Ai__Custom_Exception__c(
    Name = 'Test Retry 7',
    EmailToLead_Ai__Retry_Status__c = 'Pending',
    EmailToLead_Ai__Retry_Count__c = 0,
    EmailToLead_Ai__Next_Retry_Time__c = System.now().addMinutes(-10),
    EmailToLead_Ai__Email_Header__c = 'From: james.taylor@stateuniversity.edu\nTo: sales@company.com\nSubject: Campus outdoor seating shade\n\nDear Sir/Madam,\n\nI am Dr. James Taylor, Dean of Student Affairs at State University, 1200 University Blvd, Miami, FL 33101. We are upgrading our campus outdoor seating areas and need permanent shade structures.\n\nWe need coverage for 3 separate areas totaling 5000 sq ft. Budget allocation is $200,000.\n\nPlease send proposals to james.taylor@stateuniversity.edu or call 305-555-3210.',
    EmailToLead_Ai__Email_Body__c = 'University campus shade project',
    EmailToLead_Ai__Class_Name__c = 'EmailToLeadService',
    EmailToLead_Ai__Type__c = 'Exception',
    EmailToLead_Ai__Exception_message__c = 'Callout exception - read timed out'
));

// Record 8 - Sports facility
records.add(new EmailToLead_Ai__Custom_Exception__c(
    Name = 'Test Retry 8',
    EmailToLead_Ai__Retry_Status__c = 'Pending',
    EmailToLead_Ai__Retry_Count__c = 0,
    EmailToLead_Ai__Next_Retry_Time__c = System.now().addMinutes(-10),
    EmailToLead_Ai__Email_Header__c = 'From: mike.brown@sportsarena.com\nTo: sales@company.com\nSubject: Spectator shade for sports complex\n\nHi,\n\nI am Mike Brown, General Manager at City Sports Arena, 400 Stadium Way, Dallas, TX 75201. We need shade structures for our spectator seating areas at our outdoor sports complex.\n\nWe host baseball and soccer events and need bleacher coverage for approximately 2000 seats. Budget is $150,000.\n\nReach me at mike.brown@sportsarena.com or 214-555-6789.',
    EmailToLead_Ai__Email_Body__c = 'Sports arena shade inquiry',
    EmailToLead_Ai__Class_Name__c = 'EmailToLeadService',
    EmailToLead_Ai__Type__c = 'Exception',
    EmailToLead_Ai__Exception_message__c = 'API returned malformed JSON'
));

// Record 9 - Hospital
records.add(new EmailToLead_Ai__Custom_Exception__c(
    Name = 'Test Retry 9',
    EmailToLead_Ai__Retry_Status__c = 'Pending',
    EmailToLead_Ai__Retry_Count__c = 0,
    EmailToLead_Ai__Next_Retry_Time__c = System.now().addMinutes(-10),
    EmailToLead_Ai__Email_Header__c = 'From: nancy.white@mercyhospital.org\nTo: sales@company.com\nSubject: Shade for patient garden area\n\nHello,\n\nMy name is Nancy White, Facilities Manager at Mercy General Hospital, 750 Health Drive, Portland, OR 97201. We are building a healing garden for patients and need shade structures for the walkways and seating areas.\n\nTotal area is 2500 sq ft. Budget approved is $60,000.\n\nPlease contact me at nancy.white@mercyhospital.org or 503-555-4567.',
    EmailToLead_Ai__Email_Body__c = 'Hospital garden shade project',
    EmailToLead_Ai__Class_Name__c = 'EmailToLeadService',
    EmailToLead_Ai__Type__c = 'Exception',
    EmailToLead_Ai__Exception_message__c = 'Unexpected error during lead creation'
));

// Record 10 - HOA community
records.add(new EmailToLead_Ai__Custom_Exception__c(
    Name = 'Test Retry 10',
    EmailToLead_Ai__Retry_Status__c = 'Pending',
    EmailToLead_Ai__Retry_Count__c = 0,
    EmailToLead_Ai__Next_Retry_Time__c = System.now().addMinutes(-10),
    EmailToLead_Ai__Email_Header__c = 'From: kevin.lee@sunsethoaboard.com\nTo: sales@company.com\nSubject: Pool area shade for community\n\nDear Team,\n\nI am Kevin Lee, HOA Board President at Sunset Ridge Community, 1800 Sunset Blvd, Las Vegas, NV 89101. Our community pool area needs shade structures for the lounging and picnic areas.\n\nWe have 200 homes in our community. The pool area is 4000 sq ft and we need at least 50% coverage. Our HOA budget for this project is $85,000.\n\nEmail: kevin.lee@sunsethoaboard.com\nPhone: 702-555-8901',
    EmailToLead_Ai__Email_Body__c = 'HOA pool shade project',
    EmailToLead_Ai__Class_Name__c = 'EmailToLeadService',
    EmailToLead_Ai__Type__c = 'Exception',
    EmailToLead_Ai__Exception_message__c = 'DML exception - required field missing'
));

insert records;
System.debug('SUCCESS: Created ' + records.size() + ' test Custom Exception records');

Integer pendingCount = [SELECT COUNT() FROM EmailToLead_Ai__Custom_Exception__c WHERE EmailToLead_Ai__Retry_Status__c = 'Pending' AND EmailToLead_Ai__Next_Retry_Time__c <= :System.now()];
System.debug('Total eligible pending records: ' + pendingCount);
