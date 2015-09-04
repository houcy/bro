##! This is the notice framework which enables Bro to "notice" things which
##! are odd or potentially bad.  Decisions of the meaning of various notices
##! need to be done per site because Bro does not ship with assumptions about
##! what is bad activity for sites.  More extensive documentation about using
##! the notice framework can be found in :doc:`/frameworks/notice`.

module Notice;

export {
	redef enum Log::ID += {
		## This is the primary logging stream for notices.
		LOG,
		## This is the alarm stream.
		ALARM_LOG,
	};

	## Scripts creating new notices need to redef this enum to add their
	## own specific notice types which would then get used when they call
	## the :bro:id:`NOTICE` function.  The convention is to give a general
	## category along with the specific notice separating words with
	## underscores and using leading capitals on each word except for
	## abbreviations which are kept in all capitals. For example,
	## SSH::Password_Guessing is for hosts that have crossed a threshold of
	## failed SSH logins.
	type Type: enum {
		## Notice reporting a count of how often a notice occurred.
		Tally,
	};

	## These are values representing actions that can be taken with notices.
	type Action: enum {
		## Indicates that there is no action to be taken.
		ACTION_NONE,
		## Indicates that the notice should be sent to the notice
		## logging stream.
		ACTION_LOG,
		## Indicates that the notice should be sent to the email
		## address(es) configured in the :bro:id:`Notice::mail_dest`
		## variable.
		ACTION_EMAIL,
		## Indicates that the notice should be alarmed.  A readable
		## ASCII version of the alarm log is emailed in bulk to the
		## address(es) configured in :bro:id:`Notice::mail_dest`.
		ACTION_ALARM,
	};

	type ActionSet: set[Notice::Action];

	## The notice framework is able to do automatic notice suppression by
	## utilizing the *identifier* field in :bro:type:`Notice::Info` records.
	## Set this to "0secs" to completely disable automated notice
	## suppression.
	const default_suppression_interval = 1hrs &redef;

	type Info: record {
		## An absolute time indicating when the notice occurred,
		## defaults to the current network time.
		ts:             time           &log &optional;

		## A connection UID which uniquely identifies the endpoints
		## concerned with the notice.
		uid:            string         &log &optional;

		## A connection 4-tuple identifying the endpoints concerned
		## with the notice.
		id:             conn_id        &log &optional;

		## A shorthand way of giving the uid and id to a notice.  The
		## reference to the actual connection will be deleted after
		## applying the notice policy.
		conn:           connection     &optional;
		## A shorthand way of giving the uid and id to a notice.  The
		## reference to the actual connection will be deleted after
		## applying the notice policy.
		iconn:          icmp_conn      &optional;

		## A file record if the notice is related to a file.  The
		## reference to the actual fa_file record will be deleted after
		## applying the notice policy.
		f:              fa_file         &optional;

		## A file unique ID if this notice is related to a file.  If
		## the *f* field is provided, this will be automatically filled
		## out.
		fuid:           string          &log &optional;

		## A mime type if the notice is related to a file.  If the *f*
		## field is provided, this will be automatically filled out.
		file_mime_type: string          &log &optional;

		## Frequently files can be "described" to give a bit more
		## context.  This field will typically be automatically filled
		## out from an fa_file record.  For example, if a notice was
		## related to a file over HTTP, the URL of the request would
		## be shown.
		file_desc:      string          &log &optional;

		## The transport protocol. Filled automatically when either
		## *conn*, *iconn* or *p* is specified.
		proto:          transport_proto &log &optional;

		## The :bro:type:`Notice::Type` of the notice.
		note:           Type           &log;
		## The human readable message for the notice.
		msg:            string         &log &optional;
		## The human readable sub-message.
		sub:            string         &log &optional;

		## Source address, if we don't have a :bro:type:`conn_id`.
		src:            addr           &log &optional;
		## Destination address.
		dst:            addr           &log &optional;
		## Associated port, if we don't have a :bro:type:`conn_id`.
		p:              port           &log &optional;
		## Associated count, or perhaps a status code.
		n:              count          &log &optional;

		## Peer that raised this notice.
		src_peer:       event_peer     &optional;
		## Textual description for the peer that raised this notice.
		peer_descr:     string         &log &optional;

		## The actions which have been applied to this notice.
		actions:        ActionSet      &log &default=ActionSet();

		## By adding chunks of text into this element, other scripts
		## can expand on notices that are being emailed.  The normal
		## way to add text is to extend the vector by handling the
		## :bro:id:`Notice::notice` event and modifying the notice in
		## place.
		email_body_sections:  vector of string &optional;

		## Adding a string "token" to this set will cause the notice
		## framework's built-in emailing functionality to delay sending
		## the email until either the token has been removed or the
		## email has been delayed for :bro:id:`Notice::max_email_delay`.
		email_delay_tokens:   set[string] &optional;

		## This field is to be provided when a notice is generated for
		## the purpose of deduplicating notices.  The identifier string
		## should be unique for a single instance of the notice.  This
		## field should be filled out in almost all cases when
		## generating notices to define when a notice is conceptually
		## a duplicate of a previous notice.
		##
		## For example, an SSL certificate that is going to expire soon
		## should always have the same identifier no matter the client
		## IP address that connected and resulted in the certificate
		## being exposed.  In this case, the resp_h, resp_p, and hash
		## of the certificate would be used to create this value.  The
		## hash of the cert is included because servers can return
		## multiple certificates on the same port.
		##
		## Another example might be a host downloading a file which
		## triggered a notice because the MD5 sum of the file it
		## downloaded was known by some set of intelligence.  In that
		## case, the orig_h (client) and MD5 sum would be used in this
		## field to dedup because if the same file is downloaded over
		## and over again you really only want to know about it a
		## single time.  This makes it possible to send those notices
		## to email without worrying so much about sending thousands
		## of emails.
		identifier:          string         &optional;

		## This field indicates the length of time that this
		## unique notice should be suppressed.
		suppress_for:        interval       &log &default=default_suppression_interval;
	};

	## Ignored notice types.
	const ignored_types: set[Notice::Type] = {} &redef;
	## Emailed notice types.
	const emailed_types: set[Notice::Type] = {} &redef;
	## Alarmed notice types.
	const alarmed_types: set[Notice::Type] = {} &redef;
	## Types that should be suppressed for the default suppression interval.
	const not_suppressed_types: set[Notice::Type] = {} &redef;
	## This table can be used as a shorthand way to modify suppression
	## intervals for entire notice types.
	const type_suppression_intervals: table[Notice::Type] of interval = {} &redef;

	## The hook to modify notice handling.
	global policy: hook(n: Notice::Info);

	## Local system sendmail program.
	##
	## Note that this is overridden by the BroControl SendMail option.
	const sendmail            = "/usr/sbin/sendmail" &redef;
	## Email address to send notices with the
	## :bro:enum:`Notice::ACTION_EMAIL` action or to send bulk alarm logs
	## on rotation with :bro:enum:`Notice::ACTION_ALARM`.
	##
	## Note that this is overridden by the BroControl MailTo option.
	const mail_dest           = ""                   &redef;

	## Address that emails will be from.
	##
	## Note that this is overridden by the BroControl MailFrom option.
	const mail_from           = "Big Brother <bro@localhost>" &redef;
	## Reply-to address used in outbound email.
	const reply_to            = "" &redef;
	## Text string prefixed to the subject of all emails sent out.
	##
	## Note that this is overridden by the BroControl MailSubjectPrefix
	## option.
	const mail_subject_prefix = "[Bro]" &redef;
	## The maximum amount of time a plugin can delay email from being sent.
	const max_email_delay     = 15secs &redef;

	## Contains a portion of :bro:see:`fa_file` that's also contained in
	## :bro:see:`Notice::Info`.
	type FileInfo: record {
		fuid: string;            ##< File UID.
		desc: string;            ##< File description from e.g.
		                         ##< :bro:see:`Files::describe`.
		mime: string  &optional; ##< Strongest mime type match for file.
		cid:  conn_id &optional; ##< Connection tuple over which file is sent.
		cuid: string  &optional; ##< Connection UID over which file is sent.
	};

	## Creates a record containing a subset of a full :bro:see:`fa_file` record.
	##
	## f: record containing metadata about a file.
	##
	## Returns: record containing a subset of fields copied from *f*.
	global create_file_info: function(f: fa_file): Notice::FileInfo;

	## Populates file-related fields in a notice info record.
	##
	## f: record containing metadata about a file.
	##
	## n: a notice record that needs file-related fields populated.
	global populate_file_info: function(f: fa_file, n: Notice::Info);

	## Populates file-related fields in a notice info record.
	##
	## fi: record containing metadata about a file.
	##
	## n: a notice record that needs file-related fields populated.
	global populate_file_info2: function(fi: Notice::FileInfo, n: Notice::Info);

	## A log postprocessing function that implements emailing the contents
	## of a log upon rotation to any configured :bro:id:`Notice::mail_dest`.
	## The rotated log is removed upon being sent.
	##
	## info: A record containing the rotated log file information.
	##
	## Returns: True.
	global log_mailing_postprocessor: function(info: Log::RotationInfo): bool;

	## This is the event that is called as the entry point to the
	## notice framework by the global :bro:id:`NOTICE` function.  By the
	## time this event is generated, default values have already been
	## filled out in the :bro:type:`Notice::Info` record and the notice
	## policy has also been applied.
	##
	## n: The record containing notice data.
	global notice: hook(n: Info);

	## This event is generated when a notice begins to be suppressed.
	##
	## n: The record containing notice data regarding the notice type
	##    about to be suppressed.
	global begin_suppression: event(n: Notice::Info);

	## A function to determine if an event is supposed to be suppressed.
	##
	## n: The record containing the notice in question.
	global is_being_suppressed: function(n: Notice::Info): bool;

	## This event is generated on each occurrence of an event being
	## suppressed.
	##
	## n: The record containing notice data regarding the notice type
	##    being suppressed.
	global suppressed: event(n: Notice::Info);

	## Call this function to send a notice in an email.  It is already used
	## by default with the built in :bro:enum:`Notice::ACTION_EMAIL` and
	## :bro:enum:`Notice::ACTION_PAGE` actions.
	##
	## n: The record of notice data to email.
	##
	## dest: The intended recipient of the notice email.
	##
	## extend: Whether to extend the email using the
	##         ``email_body_sections`` field of *n*.
	global email_notice_to: function(n: Info, dest: string, extend: bool);

	## Constructs mail headers to which an email body can be appended for
	## sending with sendmail.
	##
	## subject_desc: a subject string to use for the mail.
	##
	## dest: recipient string to use for the mail.
	##
	## Returns: a string of mail headers to which an email body can be
	##          appended.
	global email_headers: function(subject_desc: string, dest: string): string;

	## This event can be handled to access the :bro:type:`Notice::Info`
	## record as it is sent on to the logging framework.
	##
	## rec: The record containing notice data before it is logged.
	global log_notice: event(rec: Info);

	## This is an internal wrapper for the global :bro:id:`NOTICE`
	## function; disregard.
	##
	## n: The record of notice data.
	global internal_NOTICE: function(n: Notice::Info);
}

# This is used as a hack to implement per-item expiration intervals.
function per_notice_suppression_interval(t: table[Notice::Type, string] of time, idx: any): interval
	{
	local n: Notice::Type;
	local s: string;
	[n,s] = idx;

	local suppress_time = t[n,s] - network_time();
	if ( suppress_time < 0secs )
		suppress_time = 0secs;

	return suppress_time;
	}

# This is the internally maintained notice suppression table.  It's
# indexed on the Notice::Type and the $identifier field from the notice.
global suppressing: table[Type, string] of time = {}
		&create_expire=0secs
		&expire_func=per_notice_suppression_interval;

function log_mailing_postprocessor(info: Log::RotationInfo): bool
	{
	if ( ! reading_traces() && mail_dest != "" )
		{
		local headers = email_headers(fmt("Log Contents: %s", info$fname),
		                              mail_dest);
		local tmpfilename = fmt("%s.mailheaders.tmp", info$fname);
		local tmpfile = open(tmpfilename);
		write_file(tmpfile, headers);
		close(tmpfile);
		system(fmt("/bin/cat %s %s | %s -t -oi && /bin/rm %s %s",
		       tmpfilename, info$fname, sendmail, tmpfilename, info$fname));
		}
	return T;
	}

event bro_init() &priority=5
	{
	Log::create_stream(Notice::LOG, [$columns=Info, $ev=log_notice, $path="notice"]);

	Log::create_stream(Notice::ALARM_LOG, [$columns=Notice::Info, $path="notice_alarm"]);
	# If Bro is configured for mailing notices, set up mailing for alarms.
	# Make sure that this alarm log is also output as text so that it can
	# be packaged up and emailed later.
	if ( ! reading_traces() && mail_dest != "" )
		Log::add_filter(Notice::ALARM_LOG,
		    [$name="alarm-mail", $path="alarm-mail", $writer=Log::WRITER_ASCII,
		     $interv=24hrs, $postprocessor=log_mailing_postprocessor]);
	}

function notice_tags(n: Notice::Info) : table[string] of string
	{
	local tgs: table[string] of string = table();
        # Get time
        local t = is_remote_event() ? current_time() : network_time();
	# If there is a ts, use that, otherwise use t
	tgs["t"] = n?$ts ? fmt("%.06f", n$ts) : fmt("%.06f", t);
	tgs["uid"] = n?$uid ? n$uid : "";
        tgs["id"] = n?$id ? id_string(n$id): "";
        tgs["fuid"] = n?$fuid ? n$fuid : "";
        tgs["file_mime_type"] = n?$file_mime_type ? n$file_mime_type : "";
        tgs["file_desc"] = n?$file_desc ? n$file_desc : "";
        tgs["proto"] =  n?$proto ? fmt("%s", n$proto) : "";;
        tgs["no"] = fmt("%s", n$note);

	tgs["msg"] = n?$msg ? n$msg : "";
	tgs["sub"] = n?$sub ? n$sub : "";

	tgs["sa"] = n?$src ? fmt("%s", n$src) : "";
	tgs["da"] = n?$dst ? fmt("%s", n$dst) : "";
	tgs["p"] = n?$p ? fmt("%s", n$p) : "";
	tgs["num"] = n?$n ? fmt("%s", n$n) : "";
	tgs["src_peer"] = n?$src_peer ? fmt("%s", n$src_peer) : "";
	tgs["peer_descr"] = n?$peer_descr ? n$peer_descr : "";

	tgs["actions"] = "";
	if (n?$actions) {
		local actionstr = "";
		for (a in n$actions) {
			actionstr = actionstr + " " + fmt("%s", a);
		}		
		tgs["actions"] = actionstr;
	}
	tgs["identifier"] = n?$identifier ? n$identifier : "";;
	tgs["suppress_for"] = n?$suppress_for ? fmt("%s", n$suppress_for) : "";

	if ( is_remote_event() )
		{
		if ( n$src_peer$descr != "" )
			tgs["es"] = n$src_peer$descr;
		else
			tgs["es"] = fmt("%s/%s", n$src_peer$host, n$src_peer$p);
		}
	else
		{
		tgs["es"] = peer_description;
		}
	return tgs;
	}

function email_headers(subject_desc: string, dest: string): string
	{
	local header_text = string_cat(
		"From: ", mail_from, "\n",
		"Subject: ", mail_subject_prefix, " ", subject_desc, "\n",
		"To: ", dest, "\n",
		"User-Agent: Bro-IDS/", bro_version(), "\n");
	if ( reply_to != "" )
		header_text = string_cat(header_text, "Reply-To: ", reply_to, "\n");
	return header_text;
	}

event delay_sending_email(n: Notice::Info, dest: string, extend: bool)
	{
	email_notice_to(n, dest, extend);
	}

function email_notice_to(n: Notice::Info, dest: string, extend: bool)
	{
	if ( reading_traces() || dest == "" )
		return;

	if ( extend )
		{
		if ( |n$email_delay_tokens| > 0 )
			{
			# If we still are within the max_email_delay, keep delaying.
			if ( n$ts + max_email_delay > network_time() )
				{
				schedule 1sec { delay_sending_email(n, dest, extend) };
				return;
				}
			else
				{
				Reporter::info(fmt("Notice email delay tokens weren't released in time (%s).", n$email_delay_tokens));
				}
			}
		}

	local email_text = email_headers(fmt("%s", n$note), dest);

	# First off, finish the headers and include the human readable messages
	# then leave a blank line after the message.
	email_text = string_cat(email_text, "\nMessage: ", n$msg, "\n");

	if ( n?$sub )
		email_text = string_cat(email_text, "Sub-message: ", n$sub, "\n");

	email_text = string_cat(email_text, "\n");

	# Add information about the file if it exists.
	if ( n?$file_desc )
		email_text = string_cat(email_text, "File Description: ", n$file_desc, "\n");

	if ( n?$file_mime_type )
		email_text = string_cat(email_text, "File MIME Type: ", n$file_mime_type, "\n");

	if ( n?$file_desc || n?$file_mime_type )
		email_text = string_cat(email_text, "\n");

	# Next, add information about the connection if it exists.
	if ( n?$id )
		{
		email_text = string_cat(email_text, "Connection: ",
			fmt("%s", n$id$orig_h), ":", fmt("%d", n$id$orig_p), " -> ",
			fmt("%s", n$id$resp_h), ":", fmt("%d", n$id$resp_p), "\n");
		if ( n?$uid )
			email_text = string_cat(email_text, "Connection uid: ", n$uid, "\n");
		}
	else if ( n?$src )
		email_text = string_cat(email_text, "Address: ", fmt("%s", n$src), "\n");

	# Add the extended information if it's requested.
	if ( extend )
		{
		email_text = string_cat(email_text, "\nEmail Extensions\n");
		email_text = string_cat(email_text,   "----------------\n");
		for ( i in n$email_body_sections )
			{
			email_text = string_cat(email_text, n$email_body_sections[i], "\n");
			}
		}

	email_text = string_cat(email_text, "\n\n--\n[Automatically generated]\n\n");
	piped_exec(fmt("%s -t -oi", sendmail), email_text);
	}

hook Notice::policy(n: Notice::Info) &priority=10
	{
	if ( n$note in Notice::ignored_types )
		break;

	if ( n$note in Notice::not_suppressed_types )
		n$suppress_for=0secs;
	if ( n$note in Notice::alarmed_types )
		add n$actions[ACTION_ALARM];
	if ( n$note in Notice::emailed_types )
		add n$actions[ACTION_EMAIL];

	if ( n$note in Notice::type_suppression_intervals )
		n$suppress_for=Notice::type_suppression_intervals[n$note];

	# Logging is a default action.  It can be removed in a later hook if desired.
	add n$actions[ACTION_LOG];
	}

hook Notice::notice(n: Notice::Info) &priority=-5
	{
	if ( ACTION_EMAIL in n$actions )
		email_notice_to(n, mail_dest, T);
	if ( ACTION_LOG in n$actions )
		Log::write(Notice::LOG, n);
	if ( ACTION_ALARM in n$actions )
		Log::write(Notice::ALARM_LOG, n);

	# Normally suppress further notices like this one unless directed not to.
	#  n$identifier *must* be specified for suppression to function at all.
	if ( n?$identifier &&
	     [n$note, n$identifier] !in suppressing &&
	     n$suppress_for != 0secs )
		{
		local suppress_until = n$ts + n$suppress_for;
		suppressing[n$note, n$identifier] = suppress_until;
		event Notice::begin_suppression(n);
		}
	}

function is_being_suppressed(n: Notice::Info): bool
	{
	if ( n?$identifier && [n$note, n$identifier] in suppressing )
		{
		event Notice::suppressed(n);
		return T;
		}
	else
		return F;
	}

# Executes a script with all of the notice fields put into the
# new process' environment as "BRO_ARG_<field>" variables.
function execute_with_notice(cmd: string, n: Notice::Info)
	{
	local tgs = notice_tags(n);
	system_env(cmd, tgs);
	}

function create_file_info(f: fa_file): Notice::FileInfo
	{
	local fi: Notice::FileInfo = Notice::FileInfo($fuid = f$id,
	                                              $desc = Files::describe(f));

	if ( f?$info && f$info?$mime_type )
		fi$mime = f$info$mime_type;

	if ( f?$conns && |f$conns| == 1 )
		for ( id in f$conns )
			{
			fi$cid = id;
			fi$cuid = f$conns[id]$uid;
			}

	return fi;
	}

function populate_file_info(f: fa_file, n: Notice::Info)
	{
	populate_file_info2(create_file_info(f), n);
	}

function populate_file_info2(fi: Notice::FileInfo, n: Notice::Info)
	{
	if ( ! n?$fuid )
		n$fuid = fi$fuid;

	if ( ! n?$file_mime_type && fi?$mime )
		n$file_mime_type = fi$mime;

	n$file_desc = fi$desc;
	n$id = fi$cid;
	n$uid = fi$cuid;
	}

# This is run synchronously as a function before all of the other
# notice related functions and events.  It also modifies the
# :bro:type:`Notice::Info` record in place.
function apply_policy(n: Notice::Info)
	{
	# Fill in some defaults.
	if ( ! n?$ts )
		n$ts = network_time();

	if ( n?$f )
		populate_file_info(n$f, n);

	if ( n?$conn )
		{
		if ( ! n?$id )
			n$id = n$conn$id;

		if ( ! n?$uid )
			n$uid = n$conn$uid;
		}

	if ( n?$id )
		{
		if ( ! n?$src  )
			n$src = n$id$orig_h;
		if ( ! n?$dst )
			n$dst = n$id$resp_h;
		if ( ! n?$p )
			n$p = n$id$resp_p;
		}

	if ( n?$p )
		n$proto = get_port_transport_proto(n$p);

	if ( n?$iconn )
		{
		n$proto = icmp;
		if ( ! n?$src )
			n$src = n$iconn$orig_h;
		if ( ! n?$dst )
			n$dst = n$iconn$resp_h;
		}

	if ( ! n?$src_peer )
		n$src_peer = get_event_peer();
	if ( ! n?$peer_descr )
		n$peer_descr = n$src_peer?$descr ?
		                   n$src_peer$descr : fmt("%s", n$src_peer$host);

	if ( ! n?$email_body_sections )
		n$email_body_sections = vector();
	if ( ! n?$email_delay_tokens )
		n$email_delay_tokens = set();

	# Apply the hook based policy.
	hook Notice::policy(n);

	# Apply the suppression time after applying the policy so that policy
	# items can give custom suppression intervals.  If there is no
	# suppression interval given yet, the default is applied.
	if ( ! n?$suppress_for )
		n$suppress_for = default_suppression_interval;

	# Delete the connection and file records if they're there so we
	# aren't sending that to remote machines.  It can cause problems
	# due to the size of those records.
	if ( n?$conn )
		delete n$conn;
	if ( n?$iconn )
		delete n$iconn;
	if ( n?$f )
		delete n$f;
	}

function internal_NOTICE(n: Notice::Info)
	{
	# Fill out fields that might be empty and do the policy processing.
	apply_policy(n);

	# Generate the notice event with the notice.
	hook Notice::notice(n);
	}

module GLOBAL;

global NOTICE: function(n: Notice::Info);
